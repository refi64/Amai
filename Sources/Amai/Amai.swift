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


class WidgetWrapper: Equatable, Hashable {
    var widget: Widget

    init(wraps widget: Widget) {
        self.widget = widget
    }

    static func == (lhs: WidgetWrapper, rhs: WidgetWrapper) -> Bool {
        if lhs.widget.key != nil && rhs.widget.key != nil {
            return lhs.widget.key === rhs.widget.key
        }
        else if lhs.widget.key == nil && rhs.widget.key == nil {
            return lhs.widget.equals(rhs.widget)
        } else {
            return false
        }
    }

    var hashValue: Int {
        if let key = widget.key {
            return key.hashValue
        } else {
            return widget.hashValue
        }
    }
}

func updateNodeIfNecessary(node: RenderNode?, widget: RenderWidget,
                           onChange: (RenderNode) -> Void) {
    let applicationResult = node?.applyChanges(widget) ??
                            RenderApplicationResult.newNode(
                                node: widget.buildRenderNode())
    if case RenderApplicationResult.newNode(let newNode) = applicationResult {
        onChange(newNode)
    }
}


public class BuildContext {
    var activeStates: [WidgetWrapper: State] = [:]
    var reActiveStates: [WidgetWrapper: State] = [:]
    var rootNode: RenderNode? = nil

    let maxIterations = 500

    func build(widget: Widget) -> RenderWidget {
        var current = widget

        for _ in 0..<maxIterations {
            switch current {
            case let stateless as StatelessWidget:
                current = stateless.build(ctx: self)
            case let stateful as StatefulWidget:
                let wrapper = WidgetWrapper(wraps: current)
                let state = activeStates[wrapper] ?? stateful.createState()
                reActiveStates[wrapper] = state
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


public protocol TypeErasedHashable {
    func equals(_ rhs: TypeErasedHashable) -> Bool
    var hashValue: Int { get }
}


extension TypeErasedHashable where Self: Hashable {
    public func equals(_ rhs: TypeErasedHashable) -> Bool {
        guard let rhsSelf = rhs as? Self else {
            return false
        }
        return self == rhsSelf
    }

    public var hashValue: Int {
        return self.hashValue
    }
}


extension Bool: TypeErasedHashable {}
extension Int: TypeErasedHashable {}
extension String: TypeErasedHashable {}
extension Key: TypeErasedHashable {}


struct TypeErasedHashableList: TypeErasedHashable {
    var items: [TypeErasedHashable] = []

    public func equals(_ rhs: TypeErasedHashable) -> Bool {
        guard let rhsSelf = rhs as? TypeErasedHashableList else {
            return false
        }

        return
            items.count == rhsSelf.items.count &&
            zip(items, rhsSelf.items).reduce(true, { (out, items) in
                let (lhsItem, rhsItem) = items
                return out && lhsItem.equals(rhsItem)
            })
    }

    public var hashValue: Int {
        return items.reduce(0, { (current: Int, item) in
            return current ^ (item.hashValue + 0x9e3779b9 + (current << 6) +
                              (current >> 2))
        })
    }
}


public protocol AutoTypeErasedHashable {
}


class AutoTypeErasedHashableRegister {
    typealias MapCallback<Type> = (Type) -> [TypeErasedHashable]
    typealias ErasedMapCallback = (Any) -> [TypeErasedHashable]

    static var callbacks: [String: ErasedMapCallback] = [:]

    static func genericName(of tp: Any.Type) -> String? {
        let descr = String(describing: tp)
        return descr.contains("<") ?
                String(descr.split(separator: "<", maxSplits: 1)[0]) : nil
    }

    public static func register<Type>(_ tp: Type.Type,
                                      _ callback: @escaping MapCallback<Type>) {
        guard let name = genericName(of: tp) else {
            preconditionFailure("\(tp) is not a generic type.")
        }
        callbacks[name] = { callback($0 as! Type) }
    }
}


extension AutoTypeErasedHashable {
    func children<Type>(of parent: Type) -> [(label: String, value: Any)] {
        let children = Mirror(reflecting: parent).children
        return children.filter { $0.label != nil }.map { ($0.label!, $0.value) }
    }

    func toTypeErasedHashable(parentType: Any.Type, child: (label: String, value: Any))
                              -> TypeErasedHashable {
        if let generic = AutoTypeErasedHashableRegister.genericName(
                            of: type(of: child.value)) {
            guard let cb = AutoTypeErasedHashableRegister.callbacks[generic] else {
                preconditionFailure("\(parentType) has no generic callback registered.")
            }
            return TypeErasedHashableList(items: cb(child.value))
        }

        guard let eq = child.value as? TypeErasedHashable else {
            let childType = type(of: child.value)
            preconditionFailure("\(parentType).\(child.label): \(childType) is not a " +
                                "TypeErasedHashable")
        }
        return eq
    }

    public func equals(_ rhs: TypeErasedHashable) -> Bool {
        let lhsType = type(of: self)
        let rhsType = type(of: rhs)
        if lhsType != rhsType {
            return false
        }

        let lhsChildren = children(of: self)
        let rhsChildren = children(of: rhs)

        for (lhsChild, rhsChild) in zip(lhsChildren, rhsChildren) {
            let lhsEq = toTypeErasedHashable(parentType: lhsType, child: lhsChild)
            let rhsEq = toTypeErasedHashable(parentType: rhsType, child: rhsChild)

            if !lhsEq.equals(rhsEq) {
                return false
            }
        }

        return true
    }

    public var hashValue: Int {
        let parentType = type(of: self)
        let items = children(of: self).map { toTypeErasedHashable(
            parentType: parentType, child: $0) }
        return TypeErasedHashableList(items: items).hashValue
    }
}


public protocol Widget: TypeErasedHashable {
    var key: Key? { get }
}

extension Widget {
    public var key: Key? { return nil }
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


public struct Window: StatelessWidget, AutoTypeErasedHashable {
    public var key: Key?
    public var title: String
    public var width: Int
    public var height: Int
    public var hasTitleBar: Bool
    public var child: Widget

    public init(key: Key? = nil, title: String = "Amai", width: Int = 800,
                height: Int = 600, hasTitleBar: Bool = true, child: Widget) {
        self.title = title
        self.width = width
        self.height = height
        self.hasTitleBar = hasTitleBar
        self.child = child
    }

    public func build(ctx: BuildContext) -> Widget {
        return WindowRenderWidget(title: title, width: width, height: height,
                                  hasTitleBar: hasTitleBar,
                                  child: ctx.build(widget: child))
    }
}


public struct Button: StatelessWidget, AutoTypeErasedHashable {
    public var key: Key?
    public var text: String

    public init(key: Key? = nil, text: String) {
        self.key = key
        self.text = text
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
    func buildRenderNode() -> RenderNode
}


protocol RenderNode {
    var ctrl: UnsafeMutablePointer<uiControl> { get }
    init(withControl ctrl: UnsafeMutablePointer<uiControl>)
    func applyChanges(_ widget: RenderWidget) -> RenderApplicationResult
    func applyChangesReceivingNode(_ widget: RenderWidget) -> RenderNode
}


extension RenderNode {
    func applyChangesReceivingNode(_ widget: RenderWidget) -> RenderNode {
        switch applyChanges(widget) {
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


struct WindowRenderWidget: RenderWidget, AutoTypeErasedHashable {
    var title: String
    var width: Int
    var height: Int
    var hasTitleBar: Bool
    var child: RenderWidget

    func buildRenderNode() -> RenderNode {
        let ctrl = uiNewWindow(title, Int32(width), Int32(height), hasTitleBar ? 1 : 0)
        let node = WindowRenderNode(withControl: UnsafeMutablePointer(ctrl!))
        return node.applyChangesReceivingNode(self)
    }
}


struct ButtonRenderWidget: RenderWidget, AutoTypeErasedHashable {
    var text: String

    func buildRenderNode() -> RenderNode {
        let ctrl = uiNewButton(text)
        let node = ButtonRenderNode(withControl: UnsafeMutablePointer(ctrl!))
        return node.applyChangesReceivingNode(self)
    }
}


class WindowRenderNode: RenderNodeDefaults, RenderNode {
    var child: RenderNode?

    required override init(withControl ctrl: UnsafeMutablePointer<uiControl>) {
        super.init(withControl: ctrl)
    }

    func applyChanges(_ widget: RenderWidget) -> RenderApplicationResult {
        guard let window = widget as? WindowRenderWidget else {
            return RenderApplicationResult.newNode(node: widget.buildRenderNode())
        }

        updateNodeIfNecessary(node: child, widget: window.child, onChange: {n in
            child = n
            uiWindowSetChild(OpaquePointer(ctrl), child!.ctrl)
        })

        return RenderApplicationResult.keepSelf
    }
}


class ButtonRenderNode: RenderNodeDefaults, RenderNode {
    required override init(withControl ctrl: UnsafeMutablePointer<uiControl>) {
        super.init(withControl: ctrl)
    }

    func applyChanges(_ widget: RenderWidget) -> RenderApplicationResult {
        guard let button = widget as? ButtonRenderWidget else {
            return RenderApplicationResult.newNode(node: widget.buildRenderNode())
        }

        uiButtonSetText(OpaquePointer(ctrl), button.text)
        return RenderApplicationResult.keepSelf
    }
}


class GlobalContext {
    init() {
        var opts = uiInitOptions()
        if let err = uiInit(&opts) {
            fatalError("Failed to initialize libui: \(err)")
            // uiFreeInitError(err)
        }

        AutoTypeErasedHashableRegister.register(Optional<TypeErasedHashable>.self,
                                                 { $0 != nil ? [$0!] : [] })
        AutoTypeErasedHashableRegister.register(Array<TypeErasedHashable>.self,
                                                 { $0 })
    }

    deinit {
        uiUninit()
    }

    func show(root: Widget) {
        let ctx = BuildContext()
        ctx.buildIteration(root: root)
        uiMain()
    }

    static var instance = GlobalContext()
}


public func show(root: Widget) {
    GlobalContext.instance.show(root: root)
}
