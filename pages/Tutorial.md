# Tutorial

## First Steps

Create a new Swift project and add the Amai dependency:

```swift
// ...
dependencies: [
    .package(url: "https://github.com/kirbyfan64/Amai", .branch("master")),
],
```

Put this in *Sources/myproject/main.swift*:

```swift
import Amai


struct Home: StatelessWidget, HashableWidget {
    var key: Key = NullKey()

    init(key: Key? = nil) {
        self.key = key ?? AutoKey(self)
    }

    func build(ctx: BuildContext) -> Widget {
        return Window(
            title: "Hello",
            width: 200,
            height: 100,
            child: Label(text: "Hello, world!")
        )
    }
}

run(app: Application(id: "com.refi64.amai.hello", root: Home()))
```

Now run it with *swift run* to see your new GUI!

## Reactive-ness

If you're familiar with traditional GUI frameworks (e.g. Cocoa, UIKit), the above might
look rather odd. Why are we creating a home "widget"? What are keys for? Why are we
returning a window? Why are we returning *anything*?

The answer to all this is that Amai isn't a traditional GUI framework. It's more like
Flutter and React in that it's a *reactive* framework. This means that you're not really
ever *modifying* any state. See how the above widget derives from `StatelessWidget`?
That means that the widget has no concrete state associated with it. All it does when
"built" is return another widget.

If anything needs to be changed, Amai will simply call the `StatelessWidget.build`
method again, and it will modify the GUI according to the new widgets.

## Keys

The `Widget.key` property is a requirement for any `Widget`. This property is used to
compare widgets and see what's changed in them.

The `NullKey` is a basic type of key that compares via *object identity*; this means that
two `NullKey`s are considered equal if and only if they are the same object instance.
This behavior isn't really useful for comparing widgets, though. Since two different
widgets will have their own different `NullKey`s, so Amai will always think the
widgets have changed and rebuild them!

Obviously, this isn't very good. This is where `AutoKey` comes in: it takes a copy of
your widget and uses it for equality tests and hashable-ness. This means, of course,
that your widget needs to be `Hashable`; the `HashableWidget` protocol is for this.
In addition, Swift synthesizes `Equatable` and `Hashable` on structs, so you don't
need to implement `==` and `hashValue` yourself.

**TODO**: Explain stateful widgets and state, and make this tutorial suck a little less.
