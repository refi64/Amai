import Amai


struct Home: StatelessWidget, Hashable {
    var key: Key = Key()

    init() {
        self.key = AutoKey(self)
    }

    func build(ctx: BuildContext) -> Widget {
        return Window(
            title: "Amai Demo",
            child: Button(text: "Hello, world!")
        )
    }
}

show(root: Home())
