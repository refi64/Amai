import Amai


struct Home: StatelessWidget, Hashable {
    var key: Key = Key()

    init() {
        self.key = AutoKey(self)
    }

    static let onClickStaticHandler = Handler() {
        print("onClickStaticHandler")
    }

    func onClickMethod() {
        print("onClickMethod")
    }
    static let onClickMethodHandler = MethodHandler(Home.onClickMethod)

    func build(ctx: BuildContext) -> Widget {
        return Window(
            title: "Amai Demo",
            width: 200,
            height: 100,
            child: Button(
                text: "Hello, world!",
                Button.onClick => Home.onClickStaticHandler,
                Button.onClick => Home.onClickMethodHandler.bind(to: self)
            )
        )
    }
}

run(app: Application(id: "com.refi64.amai.demo", root: Home()))
