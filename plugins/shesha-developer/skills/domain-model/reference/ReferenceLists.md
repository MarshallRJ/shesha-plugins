# Reference Lists Implementation Guidelines

## Contents

- [Choosing between Code-based (enum) and Data-based Reference Lists](#choosing-between-code-based-enum-and-data-based-reference-lists)
- [Implementing Code-based (enum) Reference Lists](#implementing-code-based-enum-reference-lists)
- [Implementing Data-Based Reference Lists](#implementing-data-based-reference-lists)
- [Data Migration Methods](#data-migration-methods)
- [Multi-Value Reference Lists](#multi-value-reference-lists)
- [Useful functions for working with Multi-value reference lists](#useful-functions-for-working-with-multi-value-reference-lists)

A Reference List (sometimes referred to as Lookup values, or List of Values) refers to a standard list of values usually displayed to end-users as dropdown lists (e.g. **Titles**: Mr, Mrs, Miss, etc...; **Gender**: Male, Female; **Colour**: Red,Blue, etc...).

If an Entity's property is expected to only accept a standard list of values, a Reference List should be used. 

For efficiency and maintainability reasons, properties that store a selection from a Reference List, will store the selected item as an integer, rather than the text value of the items selected. That is why a Reference List Entity properties are usually either of type `enum` or `long`.

## Choosing between Code-based (enum) and Data-based Reference Lists

Reference Lists can be implemented in two ways: as **Code-based (enum)** or **Data-based**. The choice between these two approaches depends on the expected stability of the values in the reference list and how they will be used within the application.
### Key Considerations:
- Only implement a Reference List as an enum (i.e. Code-based), if values are not expected to change, for example, 'Days Of The Week' or 'Gender', or if business logic within the application is expected to reference the reference list/enum.
- In all other cases, the reference list should be implemented as a Data-based reference list to allow the user to update the values more easily through administration interface.
- Database migration classes and logic should not be added for enum / code-based reference lists as these are handled automatically by the Shesha framework.

## Implementing Code-based (enum) Reference Lists 

For reference lists that are not expected to change **ever**, for example, 'Days Of The Week' or 'Gender', an enum should be used.

### Implementation Steps:

1. Create a new enum to define the list of possible values. For consistency the enum name should be prefixed with `RefList`
  - Make use of the `Description` To provide an additional description, if not self-explanatory.
  - Make use of the `Display` attribute to display a more user-friendly value to the user.
2. Add the property to the entity class making use of the new enum
4. DO NOT add a database migration for enum based Reference List as the Shesha Framework updates the database automatically.
5. If the Reference List is used primarily for a specific entity, the enum definition should be placed in the same folder as the entity that uses it. For example, image the `Order` entity has a property `Status` of type `RefListOrderStatus` enum. The `RefListOrderStatus` enum file should be placed within the same folder as the `Order` entity.

<example>
``` csharp
[ReferenceList("Gender")]
public enum RefListGender: long
{
    [Description("This is for a dude")]
    [Display(Name = "Male")]
    Male = 1,

    [Description("This is for a lady")]
    [Display(Name = "Female")]
    Female = 2
}
```

Using the enum in an Entity class:
``` csharp
public class Person
{
   ...
   public RefListGender Gender { get; set; }
   ...
}
```
</example>

## Implementing Data-Based Reference Lists 

If the values of a Reference List are expected to change in the future perhaps to allow future customisation for clients or evolving needs, a Data-Driven reference list should be used.

### Implementation Steps:

1. Create a database migration to add the reference list values to the database
2. Add a new property is of type `long?` (`int` and `short` will also usually do) you wish to use the reference list for
3. Add the `[ReferenceList]` attribute to the property to map the reference list to the property

This example shows how to define a data-based reference list for locations using a database migration class. The reference list will be used in the `Person` entity to store the location of a person.

<example>

``` csharp
    [Migration(20250317111700)]
    public class M20250317111700 : OneWayMigration
    {
        public override void Up()
        {
            /* Add Locations reference list */
            this.Shesha().ReferenceListCreate("MyOrg.MyProject", "Locations")
                .SetDescription("List of Locations") // set description
                .SetNoSelectionValue(0) // set no selection value
                .AddItem(1, "New York", 1, "Some description")
                .AddItem(2, "London", 2, "Capital of England")
                .AddItem(3, "Tokyo", 3, "Capital of Japan");
        }
    }
```

``` csharp
public class Person
{
   ...
   [ReferenceList("MyOrg.MyProject", "Locations")]
   public long? Location { get; set; }
   ...
}
```
</example>


## Data Migration Methods

Beyond simply creating reference lists, Shesha provides a set of methods to manage data-based reference lists through database migration classes. These methods allow you to create, update, and delete reference list items programmatically as illustrated below.

NOTE: These messages should only be used for data-based reference lists.

``` csharp
// Create a new reference list
this.Shesha().ReferenceListCreate("MyOrg.MyProject", "Locations")
    .SetDescription("List of Locations") // set description
    .SetNoSelectionValue(0) // set no selection value
    .AddItem(1, "New York") // add item
    .AddItem(2, "London", 1, "Capital of England") // add item with description
    .AddItem(3, "Tokyo", 2, "Capital of Japan"); // add item with description and order index

// Update an existing reference list
this.Shesha().ReferenceListUpdate("MyOrg.MyProject", "Locations")
    .SetDescription("Updated list of Locations") // update description
    .SetNoSelectionValue(0) // update no selection value
    .DeleteItem(1) // delete item
    .UpdateItem(2, i => i.SetItemText("London, UK").SetDescription("Updated description").SetOrderIndex(10)) // update item
    .AddItem(4, "Paris", 3, "Capital of France"); // add new item

// Delete all items in Location reference list
this.Shesha().ReferenceListUpdate("MyOrg.MyProject", "Locations")
    .DeleteAllItems(); // delete all items

// Delete a reference list entirely
this.Shesha().ReferenceListDelete("MyOrg.MyProject", "Locations");
```

## Multi-Value Reference Lists

A basic limitation of a regular Reference List property is that it can only store a single selection from the list at once. Sometimes, it is desirable to store more than one selected item at the same time. If the list of possible options has 64 items or less, it is possible to use **Multi-value Reference Lists** to support this requirement.
(if you are interested in understanding how multiple values can get stored as a single number <a href="https://www.alanzucconi.com/2015/07/26/enum-flags-and-bitwise-operators/" target="_blank">this article</a> may be helpful)

### Implementation Steps

To implement a Multi-value reference list:
1. Add the `MultiValueReferenceList` attribute to the entity property in question
2. Make sure that the property is of type `long?` or a `enum` (depending whether you want the list of possible values to be flexible or fixed respectively
3. Define your reference list items and ensure items are assigned values that are powers of two (e.g. 1, 2, 4, 8, 16, etc...)
4. Ensure that there are **no more than 64 items** in the list

<example>

``` csharp
[ReferenceList("DaysOfTheWeek")]
[Flags]  // For multi-value ref list enums ensure the [Flags] attribute is added
public enum RefListDaysOfTheWeek
{
    None = 0,
    Monday = 1,
    Tuesday = 2,
    Wednesday = 4,
    Thursday = 8,
    Friday = 16,
    Saturday = 32,
    Sunday = 64,
}
```

Property in an Entity class:

``` csharp
[MultiValueReferenceList("DaysOfTheWeek")]
public RefListDaysOfTheWeek DaysOpen { get; set; }
```

</example>

## Useful functions for working with Multi-value reference lists
If you include the `Shesha.Extensions` namespace you will have access to a couple of useful extension functions useful for working with multi-value reference lists.

``` csharp
using Shesha.Extensions

....

// Returns a comma separated list of Reference List Item referenced by the property.
var res = myEntity.GetMultiValueReferenceListItemNames("MyMultiValProperty");

// Returns a string array listing all the items selected.
var res = myEntity.GetMultiValueReferenceListItemNamesAr("MyMultiValProperty");
...
```
