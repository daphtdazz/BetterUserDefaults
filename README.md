# BetterUserDefaults

A strongly-typed wrapper around `UserDefaults`.

So instead of doing:

```swift
let myNumber = UserDefaults.standard.integer(forKey: "myKey")
UserDefaults.standard.set(newValue, forKey: "myKey")
```

You define a schema class using the macro and interact with an instance of that:

```swift
@BetterUserDefaults
class MyUserDefaults: BetterUserDefaults {
  var myNumber: Int?
}

let UD = MyUserDefaults()

// Functionally equivalent to the two UserDefaults lines above
UD.myNumber
UD.myNumber = newValue
```

Children dictionaries are supported via arrays:

```swift
@BetterUserDefaults
class MyChild: BetterUserDefaults {
    var childValue: Int = 0  // must provide an initializer expression if non-optional
}

@BetterUserDefaults
class MyParent: BetterUserDefaults {
    var children: BetterUserDefaultsArray<MyChild>
    var childrenDefault: UDArrayType = []  // array defaults defined in separate properties using data type
}

let UD = MyParent()
let newChild = UD.children.newItem(initial: [:])
newChild.childValue == 0
newChild.childValue = 5
// etc.
```

Which means it is easy to use these as the backing store for `UITableViewDataSource`, roughly as:

```swift
class TVController: UITableViewController {
    ...
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = ...
        let child = UD.children[indexPath.item]
        cell.textLabel?.text = "Item: \(child.childValue)"
        return cell
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let srci = indexPath.item
        switch editingStyle {
        case .delete:
            self.tableView.beginUpdates()
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            UD.children.remove(at: srci)
            self.tableView.endUpdates()
        default: break
        }
    }
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let srci = sourceIndexPath.item
        let dsti = destinationIndexPath.item
        UD.children.move(from: srci, to: dsti)
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UD.children.count
    }
    ...
}
```

> ☝🏽 Note that Apple do not provide a better interface to UserDefaults probably
> because they don't want to encourage heavy usage because performance would likely
> be bad since you can only change top-level keys entirely at a time, so editing
> a single item in a large array could cause a lot of writing, but for simple small
> use cases this method is a lot nicer.
