-- Searches only. No message-writing, moving, marking, or deletion commands.
-- Shortcuts loads the installed copy from ~/Library/Scripts/Mail/.
use AppleScript version "2.7"
use framework "Foundation"
use scripting additions

on run
	try
		return my findSender()
	on error errorText number errorNumber
		if errorNumber is -128 then return
		if errorNumber is -1743 then
			set errorText to "Allow Shortcuts to control Mail and System Events in System Settings > Privacy & Security > Automation. Then try again."
		else if errorNumber is -1719 or errorNumber is -25211 or errorNumber is 1002 then
			set errorText to "Allow Shortcuts (or the runner named by macOS) in System Settings > Privacy & Security > Accessibility. Keep a Mail message-list window open, then try again. " & errorText
		else if errorNumber is -1712 then
			set errorText to "Mail did not respond within 12 seconds. Wait for Mail to finish, then try again."
		end if
		display dialog errorText with title "Find Emails From Sender" buttons {"OK"} default button "OK" giving up after 30
		return "Search stopped: " & errorText
	end try
end run

on findSender()
	with timeout of 12 seconds
		tell application "System Events"
			if not UI elements enabled then error "Accessibility access is unavailable." number 1002
			-- A global Shortcuts key must do nothing outside Mail.
			set activeAppName to name of first application process whose frontmost is true
			if activeAppName is not "Mail" then return "Mail is not active."
		end tell
		tell application "Mail"
			set chosenMessages to selection
			if (count of chosenMessages) is 0 then error "Select an email in Mail first."
			-- With multiple selections, use the first message in Mail's selection order.
			set senderText to sender of item 1 of chosenMessages
			set senderAddress to extract address from senderText
		end tell
		set senderAddress to my validatedAddress(senderAddress)
		set searchField to my mailSearchField()
		tell application "System Events" to tell process "Mail"
			if not frontmost then error "Mail lost focus. Run the shortcut again in Mail."
			set value of attribute "AXFocused" of searchField to true
			if not (value of attribute "AXFocused" of searchField) then error "Could not focus Mail's search field."
			-- Cmd+A is sent only after confirming focus in the search field.
			keystroke "a" using command down
			keystroke "from:" & senderAddress
			keystroke return
		end tell
		-- Return commits the query as Mail's native From token, not body text.
		set tokenVerified to false
		repeat 30 times
			set searchField to my mailSearchField()
			tell application "System Events"
				repeat with tokenElement in UI elements of searchField
					try
						set tokenID to value of attribute "AXIdentifier" of tokenElement
						if tokenID is in {"Mail.searchSuggestions.cell.Von", "Mail.searchSuggestions.cell.From"} and (value of tokenElement as text) is senderAddress then set tokenVerified to true
					end try
				end repeat
			end tell
			if tokenVerified then exit repeat
			delay 0.1
		end repeat
		if not tokenVerified then error "Mail did not create the expected sender filter. Review the search field before selecting or deleting results."
		-- Tahoe shows search scope as a temporary sidebar row. Select it explicitly.
		set scopeRow to missing value
		repeat 30 times
			tell application "System Events" to tell process "Mail"
				set sidebarOutline to outline 1 of scroll area 1 of splitter group 1 of window 1
				repeat with candidateRow in rows of sidebarOutline
					repeat with cellElement in UI elements of candidateRow
						if description of cellElement is in {"Alle Postfächer", "All Mailboxes"} then set scopeRow to contents of candidateRow
					end repeat
					if scopeRow is not missing value then exit repeat
				end repeat
			end tell
			if scopeRow is not missing value then exit repeat
			delay 0.1
		end repeat
		if scopeRow is missing value then error "Could not find All Mailboxes. Select it in Mail's sidebar before using the results."
		tell application "System Events" to tell process "Mail"
			select scopeRow
			if not selected of scopeRow then error "Could not confirm the All Mailboxes scope."
			-- Focus the list without selecting a message or marking one as read.
			set resultList to table 1 of scroll area 1 of splitter group 1 of splitter group 1 of window 1
			if value of attribute "AXIdentifier" of resultList is not "Mail.messageList" then error "Search is ready. Click the message list before pressing Cmd+A."
			set value of attribute "AXFocused" of resultList to true
			set focusedElement to value of attribute "AXFocusedUIElement"
			if value of attribute "AXIdentifier" of focusedElement is not "Mail.messageList" then error "Search is ready. Click the message list before pressing Cmd+A."
		end tell
		return "Searching all mailboxes for sender " & senderAddress
	end timeout
end findSender

on validatedAddress(rawAddress)
	if rawAddress is missing value then error "The selected message has no usable sender address."
	set addressString to current application's NSString's stringWithString:(rawAddress as text)
	set addressString to addressString's stringByTrimmingCharactersInSet:(current application's NSCharacterSet's whitespaceAndNewlineCharacterSet())
	-- Fail safely for malformed/ambiguous addresses instead of running a broad query.
	set matchRange to addressString's rangeOfString:"^[^\\s<>\"@:,;]+@[^\\s<>\"@:,;]+$" options:(current application's NSRegularExpressionSearch)
	if (matchRange's |length| as integer) is 0 then error "Mail could not extract one unambiguous sender email address. No search was run."
	return addressString as text
end validatedAddress

on mailSearchField()
	tell application "System Events" to tell process "Mail"
		if not frontmost then error "Mail lost focus. Run the shortcut again in Mail."
		if (count windows) is 0 then error "Open a Mail message-list window first."
		set toolbarElements to entire contents of toolbar 1 of window 1
		repeat with fieldElement in toolbarElements
			if subrole of fieldElement is "AXSearchField" then return contents of fieldElement
		end repeat
	end tell
	error "Mail's toolbar search field is unavailable. Open the main Mail window and show its toolbar."
end mailSearchField
