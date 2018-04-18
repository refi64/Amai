import CGtk


public class Key: Hashable {
    public init() {}

    public static func == (lhs: Key, rhs: Key) -> Bool {
        return lhs.equals(rhs)
    }

    public func equals(_ rhs: Key) -> Bool {
        return self === rhs
    }

    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}


public class NullKey: Key {
    public override func equals(_ rhs: Key) -> Bool {
        return true
    }

    public override var hashValue: Int {
        return 0
    }
}


public class AutoKey<Wrapped: Hashable>: Key {
    var wrapped: Wrapped

    public init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
    }

    public override func equals(_ rhs: Key) -> Bool {
        guard let rhsAutoKey = rhs as? AutoKey else {
            return false
        }
        return wrapped == rhsAutoKey.wrapped
    }

    public override var hashValue: Int {
        return wrapped.hashValue
    }
}


func getPointer<Ty: AnyObject>(fromObject object: Ty) -> UnsafeMutableRawPointer {
    return Unmanaged.passUnretained(object).toOpaque()
}


func getObject<Target: AnyObject>(fromPointer ptr: UnsafeMutableRawPointer,
                                  to: Target.Type) ->
        Target {
    return Unmanaged.fromOpaque(ptr).takeUnretainedValue()
}


func gcast<Source, Target>(_ ptr: UnsafeMutablePointer<Source>,
                           to target: Target.Type) -> UnsafeMutablePointer<Target> {
    return UnsafeMutableRawPointer(ptr).bindMemory(to: target, capacity: 1)
}


func gCallbackFrom<Func>(closure: Func) -> GCallback {
    return unsafeBitCast(closure, to: GCallback.self)
}


protocol GBindings {
    static func from(_ cself: UnsafeMutableRawPointer) -> Self
    func connect<GObj, Closure>(toObject: UnsafeMutablePointer<GObj>, signal: String,
                                closure: Closure)
}


extension GBindings where Self: AnyObject {
    static func from(_ cself: UnsafeMutableRawPointer) -> Self {
        return getObject(fromPointer: cself, to: Self.self)
    }

    func connect<GObj, Closure>(toObject object: UnsafeMutablePointer<GObj>,
                                signal: String, closure: Closure) {
        g_signal_connect_data(UnsafeMutableRawPointer(object), signal,
                              gCallbackFrom(closure: closure),
                              getPointer(fromObject: self), nil,
                              GConnectFlags(rawValue: 0))
    }
}


public class BuildContext: GBindings {
    var activeStates: [Key: State] = [:]
    var reActiveStates: [Key: State] = [:]
    var ensureUpdatedNextIteration: [State] = []
    var rootNode: RenderNode? = nil
    var app: Application
    var gtkApp: UnsafeMutablePointer<GtkApplication>
    var building: Bool = false
    var updateSourceId: guint = 0

    let maxIterations = 500

    init(app: Application) {
        self.app = app
        gtkApp = gtk_application_new(app.id, GApplicationFlags(rawValue: 0))

        let closure: @convention(c)
            (UnsafeMutablePointer<GtkApplication>,
             UnsafeMutableRawPointer) -> Void = {(app, cself) in
                BuildContext.from(cself).buildIteration()
            }
        connect(toObject: gtkApp, signal: "activate", closure: closure)
    }

    func runApp() {
        g_application_run(gcast(gtkApp, to: GApplication.self), 0, nil)
    }

    deinit {
        if (updateSourceId != 0) {
            g_source_remove(updateSourceId)
            updateSourceId = 0
        }
        g_object_unref(gtkApp)
    }

    func build(widget: Widget) -> RenderWidget {
        var current = widget

        for _ in 0..<maxIterations {
            switch current {
            case let stateless as StatelessWidget:
                current = stateless.build(ctx: self)
            case let stateful as StatefulWidget:
                let state = activeStates[current.key] ?? stateful.createState(ctx: self)
                reActiveStates[current.key] = state
                current = state.build(ctx: self)
            case let current as RenderWidget:
                return current as RenderWidget
            default:
                preconditionFailure("Invalid widget \(widget) in BuildContext.build.")
            }
        }

        preconditionFailure("Tried building \(widget), but didn't get RenderWidget " +
                            "after \(maxIterations) iterations.")
    }

    func updateNodeIfNecessary(node: RenderNode?, widget: Widget,
                               onChange: (RenderNode) -> Void) {
        let renderWidget = build(widget: widget)

        let applicationResult = node?.applyChanges(ctx: self, from: renderWidget) ??
                                RenderApplicationResult.newNode(
                                    node: renderWidget.buildRenderNode(ctx: self))
        if case RenderApplicationResult.newNode(let newNode) = applicationResult {
            onChange(newNode)
        }
    }

    func buildIteration() {
        building = true
        guard let rootRender = build(widget: app.root) as? Window else {
            preconditionFailure("Root widget must be Window.")
        }

        updateNodeIfNecessary(node: rootNode, widget: rootRender, onChange: {n in
            rootNode = n
            gtk_widget_show_all(rootNode!.gwidget)
        })

        activeStates = reActiveStates
        reActiveStates.removeAll()

        building = false
    }

    public func setState(setter: () -> Void) {
        precondition(!building, "Cannot call setState while building.")

        setter()

        if (updateSourceId == 0) {
            let closure: @convention(c) (UnsafeMutableRawPointer?) -> Int32 =
                {(cself) in
                    let ctx = BuildContext.from(cself!)
                    ctx.buildIteration()
                    ctx.updateSourceId = 0
                    return 0
                }

            updateSourceId = g_idle_add_full(G_PRIORITY_HIGH, closure,
                                             getPointer(fromObject: self), nil)
        }
    }
}


protocol TypeErasedHashable {
    func equals(_ rhs: TypeErasedHashable) -> Bool
    var hashValue: Int { get }
}


extension TypeErasedHashable where Self: AnyObject {
    func equals(_ rhs: TypeErasedHashable) -> Bool {
        guard let rhsSelf = rhs as? Self else {
            return false
        }
        return self === rhsSelf
    }

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}


struct TypeErasedHashableWrapper: Hashable {
    var inner: TypeErasedHashable

    static func == (lhs: TypeErasedHashableWrapper, rhs: TypeErasedHashableWrapper) ->
            Bool {
        return lhs.inner.equals(rhs.inner)
    }

    public var hashValue: Int {
        return inner.hashValue
    }
}


public class Handler<Func>: TypeErasedHashable {
    var function: Func

    public init(_ function: Func) {
        self.function = function
    }
}


public class MethodHandler<Parent, Func>: TypeErasedHashable {
    var method: (Parent) -> Func

    public init(_ method: @escaping (Parent) -> Func) {
        self.method = method
    }

    public func bind(to parent: Parent) -> BoundMethodHandler<Parent, Func> {
        return BoundMethodHandler(createdBy: self, function: self.method(parent))
    }
}


public class BoundMethodHandler<Parent, Func>: Handler<Func> {
    weak var creator: MethodHandler<Parent, Func>!

    public init(createdBy creator: MethodHandler<Parent, Func>, function: Func) {
        self.creator = creator
        super.init(function)
    }

    func equals(rhs: TypeErasedHashable) -> Bool {
        guard let rhsHandler = rhs as? BoundMethodHandler<Parent, Func> else {
            return false
        }
        return self.creator.equals(rhsHandler.creator)
    }

    public var hashValue: Int {
        return self.creator.hashValue
    }
}


public struct SignalConnection: Hashable {
    var signal: TypeErasedHashableWrapper
    var handler: TypeErasedHashableWrapper
}


infix operator =>


public class SignalId<Func>: TypeErasedHashable {
    public static func => (signal: SignalId<Func>, handler: Handler<Func>) ->
            SignalConnection {
        return SignalConnection(signal: TypeErasedHashableWrapper(inner: signal),
                                handler: TypeErasedHashableWrapper(inner: handler))
    }

    public static func == (lhs: SignalId<Func>, rhs: SignalId<Func>) -> Bool {
        return lhs === rhs
    }

    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}


public struct SignalConnectionGroup: Hashable {
    var connections: [SignalConnection]

    public init(_ connections: [SignalConnection]) {
        self.connections = connections
    }

    public func map<Func>(signal: SignalId<Func>, _ callback: (Func) -> Bool) {
        for connection in connections {
            guard let connSignal = connection.signal.inner as? SignalId<Func> else {
                continue
            }
            guard connSignal == signal else {
                continue
            }

            let handler = connection.handler.inner as! Handler<Func>
            if !callback(handler.function) {
                break
            }
        }
    }

    public var hashValue: Int {
        return connections.reduce(0) {(hash: Int, item) in
            hash ^ (item.hashValue + 0x9e3779b9 + (hash << 6) + (hash >> 2))
        }
    }
}


public protocol Widget {
    var key: Key { get }
}


public protocol HashableWidget: Widget, Hashable {}


public class Keyed<WidgetType>: Equatable, Hashable {
    public private(set) var widget: WidgetType

    public init(widget: WidgetType) {
        self.widget = widget
    }

    public static func == (lhs: Keyed<WidgetType>, rhs: Keyed<WidgetType>) -> Bool {
        return (lhs.widget as! Widget).key == (rhs.widget as! Widget).key
    }

    public var hashValue: Int {
        return (widget as! Widget).key.hashValue
    }
}


public protocol StatelessWidget: Widget {
    func build(ctx: BuildContext) -> Widget
}

public protocol StatefulWidget: Widget {
    func createState(ctx: BuildContext) -> State
}


public protocol State {
    var ctx: BuildContext { get }
    func build(ctx: BuildContext) -> Widget
    func setState(setter: () -> Void)
}

extension State {
    public func setState(setter: () -> Void) {
        ctx.setState(setter: setter)
    }
}


protocol RenderWidget: Widget {
    func buildRenderNode(ctx: BuildContext) -> RenderNode
}


enum RenderApplicationResult {
    case keepSelf
    case newNode(node: RenderNode)
}


public struct Window: RenderWidget, HashableWidget {
    public var key: Key = NullKey()
    public var title: String
    public var width: Int
    public var height: Int
    public var hasTitleBar: Bool
    public var child: Keyed<Widget>

    public init(key: Key? = nil, title: String = "Amai", width: Int = 800,
                height: Int = 600, hasTitleBar: Bool = true, child: Widget) {
        self.title = title
        self.width = width
        self.height = height
        self.hasTitleBar = hasTitleBar
        self.child = Keyed(widget: child)

        self.key = key ?? AutoKey(self)
    }

    func buildRenderNode(ctx: BuildContext) -> RenderNode {
        let node = WindowRenderNode(ctx: ctx)
        return node.applyChangesReceivingNode(ctx: ctx, from: self)
    }
}


public struct Button: RenderWidget, HashableWidget {
    public var key: Key = NullKey()
    public var text: String
    var connections: SignalConnectionGroup

    public init(key: Key? = nil, text: String, _ connections: SignalConnection...) {
        self.text = text
        self.connections = SignalConnectionGroup(connections)

        self.key = key ?? AutoKey(self)
    }

    func buildRenderNode(ctx: BuildContext) -> RenderNode {
        let node = ButtonRenderNode(ctx: ctx)
        return node.applyChangesReceivingNode(ctx: ctx, from: self)
    }

    public static let onClick: SignalId<() -> Void> = SignalId()
}


protocol RenderNode {
    var gwidget: UnsafeMutablePointer<GtkWidget> { get }
    init(ctx: BuildContext)
    func applyChanges(ctx: BuildContext, from widget: RenderWidget) ->
            RenderApplicationResult
    func applyChangesReceivingNode(ctx: BuildContext, from widget: RenderWidget) ->
            RenderNode
}


extension RenderNode {
    func applyChangesReceivingNode(ctx: BuildContext, from widget: RenderWidget)
            -> RenderNode {
        switch applyChanges(ctx: ctx, from: widget) {
        case .keepSelf:
            return self
        case .newNode(let node):
            return node
        }
    }
}


class RenderNodeDefaults<GtkWidgetType> {
    var gwidget: UnsafeMutablePointer<GtkWidget>
    var gwidgetCast: UnsafeMutablePointer<GtkWidgetType> {
        return gcast(gwidget, to: GtkWidgetType.self)
    }

    init(withWidget gwidget: UnsafeMutablePointer<GtkWidget>) {
        self.gwidget = gwidget
    }
}


class WindowRenderNode: RenderNodeDefaults<GtkWindow>, RenderNode {
    var child: RenderNode?

    required init(ctx: BuildContext) {
        let gwidget = UnsafeMutablePointer(gtk_application_window_new(ctx.gtkApp)!)
        super.init(withWidget: gwidget)
    }

    func applyChanges(ctx: BuildContext, from widget: RenderWidget) ->
            RenderApplicationResult {
        guard let window = widget as? Window else {
            return RenderApplicationResult.newNode(node:
                widget.buildRenderNode(ctx: ctx))
        }

        gtk_window_set_title(gwidgetCast, window.title)
        gtk_window_set_default_size(gwidgetCast, gint(window.width), gint(window.height))

        ctx.updateNodeIfNecessary(node: child, widget: window.child.widget,
            onChange: {n in
                let gcontainer = gcast(gwidget, to: GtkContainer.self)
                if (child != nil) {
                    gtk_container_remove(gcontainer, child!.gwidget)
                }
                child = n
                gtk_container_add(gcontainer, child!.gwidget)
            }
        )

        return RenderApplicationResult.keepSelf
    }
}


class ButtonRenderNode: RenderNodeDefaults<GtkButton>, RenderNode, GBindings {
    var connections: SignalConnectionGroup? = nil

    required init(ctx: BuildContext) {
        let gwidget = UnsafeMutablePointer(gtk_button_new()!)
        super.init(withWidget: gwidget)

        let closure: @convention(c)
            (UnsafeMutablePointer<GtkButton>,
             UnsafeMutableRawPointer) -> Void = {(_, cself) in
                ButtonRenderNode.from(cself).clicked()
            }
        connect(toObject: gwidget, signal: "clicked", closure: closure)
    }

    func applyChanges(ctx: BuildContext, from widget: RenderWidget) ->
            RenderApplicationResult {
        guard let button = widget as? Button else {
            return RenderApplicationResult.newNode(node:
                widget.buildRenderNode(ctx: ctx))
        }

        gtk_button_set_label(gwidgetCast, button.text)
        connections = button.connections

        return RenderApplicationResult.keepSelf
    }

    func clicked() {
        guard let connections = self.connections else {
            return
        }

        connections.map(signal: Button.onClick) { $0(); return true }
    }
}


public struct Application {
    public var id: String
    public var root: Widget

    public init(id: String, root: Widget) {
        self.id = id
        self.root = root
    }
}


public func run(app: Application) {
    let ctx = BuildContext(app: app)
    ctx.runApp()
}
