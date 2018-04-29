/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


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
    static let onClickHandler = MethodHandler(onClick)

    func build(ctx: BuildContext) -> Widget {
        return Button(
            text: "You have pressed this \(count) times.",
            Button.onClick => IncButtonState.onClickHandler.bind(to: self)
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


class NameBoxState: State {
    var ctx: BuildContext
    var nameManager = InputStateManager()
    var passManager = InputStateManager()

    init(ctx: BuildContext) {
        self.ctx = ctx
    }

    func onChanged(_ text: String) {
        print("\(text) (name: \(nameManager.text), pass: \(passManager.text))")
    }
    static let onChangedHandler = MethodHandler(onChanged)

    func build(ctx: BuildContext) -> Widget {
        return Grid(
            column: [
                Input(
                    placeholder: "Enter your name here",
                    managedBy: nameManager,
                    Input.onChanged => NameBoxState.onChangedHandler.bind(to: self)
                ),
                Input(
                    placeholder: "Enter your password here",
                    purpose: .password,
                    managedBy: passManager,
                    Input.onChanged => NameBoxState.onChangedHandler.bind(to: self)
                )
            ]
        )
    }
}


struct NameBox: StatefulWidget, Hashable {
    var key: Key = NullKey()

    init(key: Key? = nil) {
        self.key = key ?? AutoKey(self)
    }

    func createState(ctx: BuildContext) -> State {
        return NameBoxState(ctx: ctx)
    }
}


struct MessyGrid: StatelessWidget, HashableWidget {
    var key: Key = NullKey()

    init(key: Key? = nil) {
        self.key = key ?? AutoKey(self)
    }

    func build(ctx: BuildContext) -> Widget {
        return Grid(
            defaultPosition: Grid.Position.below,
            homogenous: Grid.Homogenous.all,
            items: [
                Grid.Item(
                    child: Label(text: "This is a label.")
                ),
                Grid.Item(
                    position: Grid.Position.right,
                    child: IncButton()
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
                ),
                Grid.Item(
                    from: Grid.Location.relative(x: 0, y: 1),
                    child: NameBox()
                )
            ]
        )
    }
}


struct Home: StatelessWidget, HashableWidget {
    var key: Key = NullKey()

    init(key: Key? = nil) {
        self.key = key ?? AutoKey(self)
    }

    func build(ctx: BuildContext) -> Widget {
        return Window(
            title: "Amai Demo",
            width: 200,
            height: 100,
            child: MessyGrid()
        )
    }
}

run(app: Application(id: "com.refi64.amai.demo", root: Home()))
