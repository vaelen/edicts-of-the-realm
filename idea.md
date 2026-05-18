I am going to build a mod for Crusader Kings III.  

The mod should register a decision called "Give Vassals Directives". 

When this decision is chosen, it should open a popup window titled "Give Vassals Directives" with a set of radio buttons for the user to choose between "Construct Fortification Buildings", "Construct Military Buildings", and "Construct Economic Buildings". On the same page there should be a checkbox (default checked) for "Convert to Your Faith" and another set of radio buttons to select between "Promote Your Culture" and "Improve Cultural Acceptance". By default "Promote Your Culture" and "Construct Economic Buildings" should be chosen from the radio boxes. The form should have a "Give Directives" default button at the bottom to submit the form.

When the form is submitted, the choices made should be saved somewhere, then it should trigger a function (or whatever the mod equivelent is of a function, method, procedure, etc.) that goes through all of the player's direct vassals and sets that vassal's directive based on the following pseudocode:

```
// convertFaith is true if the checkbox is checked.
// promoteCulture is true if the radio option is set to 'Promote Culture".
// newDirective is set to the chosen value from the directive radio buttons.
method SetVassalDirectives(convertFaith: bool, promoteCulture: bool, directive: Directive)
vars
    player - the current player
    playersDirectVassals - the list of vassals the player has
    vassal - a single vassal from the list (loop variable)
begin
    for vassal in playersDirectVassals
    begin
        if !CanSetDirective(vassal) then
            continue
        else if convertFaith and vassal.faith != player.faith and CanConvertFaith(vassal) then
            vassal.directive = "Convert Faith"
        else if promoteCulture and vassal.culture == player.culture and CanPromoteCulture(vassal) then
            vassal.directive = "Promote Culture"
        else if !promoteCulture and vassal.culture == player.culture and vassal.culture and CanImproveCulturalAcceptance(vassal) then
            vassal.directive = "Improve Cultural Acceptance"
        else
            vassal.directive = directive
        end
    end
end

// In theory, these three functions are already defined somewhere, because the game uses them in the regular 'Give Vassal Directive' screen that already exists.

// CanConvertFaith(vassal) returns true if the vassal controls at least one county of another faith.
// CanPromoteCulture(vassal) returns true if the vassal controls at least one county of another culture.
// CanImproveCulturalAcceptance(vassal) returns true if the vassal controls at least one county of another culture AND the cultural acceptance between the vassal's culture and that culture is less than 100%.
```

Note: I don't know what it takes to actually set the directive, but there must be a way to do it.