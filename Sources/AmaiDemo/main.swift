import Amai


struct Home: StatelessWidget, Hashable {
    var key: Key = Key()

    init() {
        self.key = AutoKey(self)
    }

    func build(ctx: BuildContext) -> Widget {
        return Window(
            title: "Amai Demo",
            width: 640,
            height: 480,
            child: Button(text: "Hello, world!")
        )
    }
}

run(app: Application(id: "com.refi64.amai.demo", root: Home()))
