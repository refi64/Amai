import Amai


class IncButtonState: State {
    var ctx: BuildContext
    var count = 0

    init(ctx: BuildContext) {
        self.ctx = ctx
    }

    func onClick() {
        setState {
            count += 1
        }
    }
    let onClickHandler = MethodHandler(IncButtonState.onClick)

    func build(ctx: BuildContext) -> Widget {
        return Grid(
            defaultPosition: Grid.Position.below,
            homogenous: Grid.Homogenous.all,
            items: [
                Grid.Item(
                    child: Button(text: "This does nothing.")
                ),
                Grid.Item(
                    position: Grid.Position.right,
                    child: Button(
                        text: "You have pressed this \(count) times.",
                        Button.onClick => onClickHandler.bind(to: self)
                    )
                ),
                Grid.Item(
                    position: Grid.Position.below,
                    child: Button(text: "This should be beneath the above")
                ),
                Grid.Item(
                    position: Grid.Position.left,
                    child: Button(text: "And going full circle")
                ),
                Grid.Item(
                    from: Grid.Location.absolute(x: 1, y: 2),
                    size: Grid.Size(x: 2, y: 2),
                    child: Button(text: "Over yonder!")
                ),
                Grid.Item(
                    from: Grid.Location.relative(x: -1, y: 0),
                    child: Button(text: "...and to the left!")
                )
            ]
        )
    }
}


struct IncButton: StatefulWidget, Hashable {
    var key: Key = NullKey()

    init(key: Key? = nil) {
        self.key = key ?? AutoKey(self)
    }

    func createState(ctx: BuildContext) -> State {
        return IncButtonState(ctx: ctx)
    }
}


struct Home: StatelessWidget, Hashable {
    var key: Key = NullKey()

    init(key: Key? = nil) {
        self.key = key ?? AutoKey(self)
    }

    // static let onClickStaticHandler = Handler() {
    //     print("onClickStaticHandler")
    // }

    // func onClickMethod() {
    //     print("onClickMethod")
    // }
    // static let onClickMethodHandler = MethodHandler(Home.onClickMethod)

    func build(ctx: BuildContext) -> Widget {
        return Window(
            title: "Amai Demo",
            width: 200,
            height: 100,
            child: IncButton()
            //     Button(
            //     text: "Hello, world!",
            //     Button.onClick => Home.onClickStaticHandler,
            //     Button.onClick => Home.onClickMethodHandler.bind(to: self)
            // )
        )
    }
}

run(app: Application(id: "com.refi64.amai.demo", root: Home()))
