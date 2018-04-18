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
    static let onClickHandler = MethodHandler(IncButtonState.onClick)

    func build(ctx: BuildContext) -> Widget {
        return Button(
            text: "You have pressed this \(count) times.",
            Button.onClick => IncButtonState.onClickHandler.bind(to: self)
        )
    }
}


struct IncButton: StatefulWidget, Hashable {
    var key: Key = NullKey()

    init() {
        self.key = AutoKey(self)
    }

    func createState(ctx: BuildContext) -> State {
        return IncButtonState(ctx: ctx)
    }
}


struct Home: StatelessWidget, Hashable {
    var key: Key = NullKey()

    init() {
        self.key = AutoKey(self)
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
