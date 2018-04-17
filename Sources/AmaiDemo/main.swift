import Amai


struct Home: StatelessWidget, AutoTypeErasedHashable {
    func build(ctx: BuildContext) -> Widget {
        return Window(
            title: "Amai Demo",
            child: Button(text: "Hello, world!")
        )
    }
}

show(root: Home())
