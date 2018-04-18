import Cui


public class Key: Hashable {
    public init() {}

    public static func == (lhs: Key, rhs: Key) -> Bool {
        return lhs === rhs
    }

    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}


public class AutoKey<Wrapped: Hashable>: Key {
    var wrapped: Wrapped

    public init(_ wrapped: Wrapped) {
        self.wrapped = wrapped
    }

    public static func == (lhs: AutoKey, rhs: AutoKey) -> Bool {
        return lhs.wrapped == rhs.wrapped
    }

    public override var hashValue: Int {
        return wrapped.hashValue
    }
}


public class BuildContext {
    var activeStates: [Key: State] = [:]
    var reActiveStates: [Key: State] = [:]
    var rootNode: RenderNode? = nil

    let maxIterations = 500

    func build(widget: Widget) -> RenderWidget {
        var current = widget

        for _ in 0..<maxIterations {
            switch current {
            case let stateless as StatelessWidget:
                current = stateless.build(ctx: self)
            case let stateful as StatefulWidget:
                let state = activeStates[current.key] ?? stateful.createState()
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

    func updateNodeIfNecessary(node: RenderNode?, widget: RenderWidget,
                               onChange: (RenderNode) -> Void) {
        let applicationResult = node?.applyChanges(ctx: self, from: widget) ??
                                RenderApplicationResult.newNode(
                                    node: widget.buildRenderNode(ctx: self))
        if case RenderApplicationResult.newNode(let newNode) = applicationResult {
            onChange(newNode)
        }
    }

    func buildIteration(root: Widget) {
        guard let rootRenderWidget = build(widget: root) as? WindowRenderWidget else {
            preconditionFailure("Root widget must be WindowRenderWidget.")
        }

        updateNodeIfNecessary(node: rootNode, widget: rootRenderWidget, onChange: {n in
            rootNode = n
            uiControlShow(rootNode!.ctrl)
        })

        activeStates = reActiveStates
        reActiveStates.removeAll()
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

public protocol State {
    func build(ctx: BuildContext) -> Widget
}

public protocol StatefulWidget: Widget {
    func createState() -> State
}


public struct Window: StatelessWidget, HashableWidget {
    public var key: Key = Key()
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

    public func build(ctx: BuildContext) -> Widget {
        return WindowRenderWidget(title: title, width: width,
                                  height: height, hasTitleBar: hasTitleBar,
                                  child: ctx.build(widget: child.widget))
    }
}


public struct Button: StatelessWidget, HashableWidget {
    public var key: Key = Key()
    public var text: String

    public init(key: Key? = nil, text: String) {
        self.text = text

        self.key = key ?? AutoKey(self)
        // self.callbacks = CallbackGroup(callbacks)

        // OnClickId.call(self.callbacks)
    }

    public func build(ctx: BuildContext) -> Widget {
        return ButtonRenderWidget(text: text)
    }

    // typealias OnClickId: CallbackId<() -> Void>
    // public func onClick(_ cb: OnClickId) -> AnyCallbackId { return OnClickId(cb) }
}


protocol RenderWidget: Widget {
    func buildRenderNode(ctx: BuildContext) -> RenderNode
}


protocol RenderNode {
    var ctrl: UnsafeMutablePointer<uiControl> { get }
    init(withControl ctrl: UnsafeMutablePointer<uiControl>)
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


class RenderNodeDefaults {
    var ctrl: UnsafeMutablePointer<uiControl>

    init(withControl ctrl: UnsafeMutablePointer<uiControl>) {
        self.ctrl = ctrl
    }
}


enum RenderApplicationResult {
    case keepSelf
    case newNode(node: RenderNode)
}


struct WindowRenderWidget: RenderWidget, Hashable {
    var key: Key = Key()
    var title: String
    var width: Int
    var height: Int
    var hasTitleBar: Bool
    var child: Keyed<RenderWidget>

    init(title: String, width: Int, height: Int, hasTitleBar: Bool,
         child: RenderWidget) {
        self.title = title
        self.width = width
        self.height = height
        self.hasTitleBar = hasTitleBar
        self.child = Keyed(widget: child)

        self.key = AutoKey(self)
    }

    func buildRenderNode(ctx: BuildContext) -> RenderNode {
        let ctrl = uiNewWindow(title, Int32(width), Int32(height), hasTitleBar ? 1 : 0)
        let node = WindowRenderNode(withControl: UnsafeMutablePointer(ctrl!))
        return node.applyChangesReceivingNode(ctx: ctx, from: self)
    }
}


struct ButtonRenderWidget: RenderWidget, Hashable {
    var key: Key = Key()
    var text: String

    init(text: String) {
        self.text = text
        self.key = AutoKey(self)
    }

    func buildRenderNode(ctx: BuildContext) -> RenderNode {
        let ctrl = uiNewButton(text)
        let node = ButtonRenderNode(withControl: UnsafeMutablePointer(ctrl!))
        return node.applyChangesReceivingNode(ctx: ctx, from: self)
    }
}


class WindowRenderNode: RenderNodeDefaults, RenderNode {
    var child: RenderNode?

    required override init(withControl ctrl: UnsafeMutablePointer<uiControl>) {
        super.init(withControl: ctrl)
    }

    func applyChanges(ctx: BuildContext, from widget: RenderWidget) ->
            RenderApplicationResult {
        guard let window = widget as? WindowRenderWidget else {
            return RenderApplicationResult.newNode(node:
                widget.buildRenderNode(ctx: ctx))
        }

        ctx.updateNodeIfNecessary(node: child, widget: window.child.widget,
            onChange: {n in
                child = n
                uiWindowSetChild(OpaquePointer(ctrl), child!.ctrl)
            }
        )

        return RenderApplicationResult.keepSelf
    }
}


class ButtonRenderNode: RenderNodeDefaults, RenderNode {
    required override init(withControl ctrl: UnsafeMutablePointer<uiControl>) {
        super.init(withControl: ctrl)
    }

    func applyChanges(ctx: BuildContext, from widget: RenderWidget) ->
            RenderApplicationResult {
        guard let button = widget as? ButtonRenderWidget else {
            return RenderApplicationResult.newNode(node:
                widget.buildRenderNode(ctx: ctx))
        }

        uiButtonSetText(OpaquePointer(ctrl), button.text)
        return RenderApplicationResult.keepSelf
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


class GlobalContext {
    init() {
        var opts = uiInitOptions()
        if let err = uiInit(&opts) {
            fatalError("Failed to initialize libui: \(err)")
            // uiFreeInitError(err)
        }
    }

    deinit {
        uiUninit()
    }

    func run(app: Application) {
        let ctx = BuildContext()
        ctx.buildIteration(root: app.root)
        uiMain()
    }

    static var instance = GlobalContext()
}


public func run(app: Application) {
    GlobalContext.instance.run(app: app)
}
