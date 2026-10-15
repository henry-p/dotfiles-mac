-- Searches only. No message-writing, moving, marking, or deletion commands.
-- Shortcuts loads the installed copy from ~/Library/Scripts/Mail/.
use AppleScript version "2.7"
use framework "Foundation"
use framework "AppKit"
use scripting additions

on run
	try
		return my findSender()
	on error errorText number errorNumber
		if errorNumber is -128 then return
		if errorNumber is -1743 then
			set errorText to "Allow Shortcuts to control Mail and System Events in System Settings > Privacy & Security > Automation. Then try again."
		else if errorNumber is -25211 or errorNumber is 1002 then
			set errorText to "Allow Shortcuts (or the runner named by macOS) in System Settings > Privacy & Security > Accessibility. Keep a Mail message-list window open, then try again. " & errorText
		else if errorNumber is -1719 then
			set errorText to "Mail's message-list window or toolbar is not ready. Close any Mail dialog, return to the message list, and try again."
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
		my waitForModifierRelease()
		set senderAddress to my validatedAddress(senderAddress)
		set originalScope to my captureMailboxScope()
		my disableMessageFilter()
		my pasteSearchQuery("from:" & senderAddress)
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
		my restoreMailboxScope(originalScope)
		tell application "System Events" to tell process "Mail"
			-- Focus the list without selecting a message or marking one as read.
			set viewerWindow to my mailViewerWindow()
			set resultList to table 1 of scroll area 1 of splitter group 1 of splitter group 1 of viewerWindow
			if value of attribute "AXIdentifier" of resultList is not "Mail.messageList" then error "Search is ready. Click the message list before pressing Cmd+A."
			set value of attribute "AXFocused" of resultList to true
			if not (value of attribute "AXFocused" of resultList) then error "Search is ready. Click the message list before pressing Cmd+A."
		end tell
		return "Searching the selected mailbox scope for sender " & senderAddress
	end timeout
end findSender

on validatedAddress(rawAddress)
	if rawAddress is missing value then error "The selected message has no usable sender address."
	set addressString to current application's NSString's stringWithString:(rawAddress as text)
	set addressString to addressString's stringByTrimmingCharactersInSet:(current application's NSCharacterSet's whitespaceAndNewlineCharacterSet())
	if (addressString's rangeOfCharacterFromSet:(current application's NSCharacterSet's controlCharacterSet()))'s |length| as integer is greater than 0 then error "The sender address contains control characters. No search was run."
	-- Fail safely for malformed/ambiguous addresses instead of running a broad query.
	set matchRange to addressString's rangeOfString:"^[^\\s<>\"@:,;]+@[^\\s<>\"@:,;]+$" options:(current application's NSRegularExpressionSearch)
	if (matchRange's |length| as integer) is 0 then error "Mail could not extract one unambiguous sender email address. No search was run."
	return addressString as text
end validatedAddress

-- Search adds two temporary rows above the mailbox tree. Store positions
-- relative to that tree, plus their labels and row count. Duplicate mailbox
-- names (for example, multiple accounts' Inbox) remain distinguishable.
on mailboxSidebarStart(sidebarOutline)
	tell application "System Events"
		if (count rows of sidebarOutline) > 1 then
			set firstLabel to description of UI element 1 of row 1 of sidebarOutline
			set secondLabel to description of UI element 1 of row 2 of sidebarOutline
			if firstLabel is in {"Suchen", "Search"} and secondLabel is in {"Alle Postfächer", "All Mailboxes"} then return 3
		end if
	end tell
	return 1
end mailboxSidebarStart

on captureMailboxScope()
	tell application "System Events" to tell process "Mail"
		set viewerWindow to my mailViewerWindow()
		set sidebarOutline to outline 1 of scroll area 1 of splitter group 1 of viewerWindow
	end tell
	set firstMailboxRow to my mailboxSidebarStart(sidebarOutline)
	set positions to {}
	set labels to {}
	tell application "System Events"
		set selectionFlags to selected of rows of sidebarOutline
		if firstMailboxRow is 3 and item 2 of selectionFlags then return {true, {}, {}, 0}
		repeat with i from firstMailboxRow to count selectionFlags
			if item i of selectionFlags then
				set end of positions to i - firstMailboxRow + 1
				set end of labels to description of UI element 1 of row i of sidebarOutline
			end if
		end repeat
		set mailboxRowCount to (count selectionFlags) - firstMailboxRow + 1
	end tell
	if positions is {} then error "Select a mailbox in Mail's sidebar first."
	return {false, positions, labels, mailboxRowCount}
end captureMailboxScope

on restoreMailboxScope(originalScope)
	set {searchAll, positions, labels, mailboxRowCount} to originalScope
	tell application "System Events" to tell process "Mail"
		set viewerWindow to my mailViewerWindow()
		set sidebarOutline to outline 1 of scroll area 1 of splitter group 1 of viewerWindow
	end tell
	set firstMailboxRow to my mailboxSidebarStart(sidebarOutline)
	if firstMailboxRow is not 3 then error "Mail's search scope is not ready. Run the shortcut again."
	tell application "System Events"
		if searchAll then
			select row 2 of sidebarOutline
		else
			if (count rows of sidebarOutline) - firstMailboxRow + 1 is not mailboxRowCount then error "Mail's sidebar changed. Select the intended mailbox and run the shortcut again."
			set scopeRows to {}
			repeat with i from 1 to count positions
				set rowNumber to (item i of positions) + firstMailboxRow - 1
				if description of UI element 1 of row rowNumber of sidebarOutline is not item i of labels then error "Mail's mailbox selection changed. Run the shortcut again."
				set end of scopeRows to row rowNumber of sidebarOutline
			end repeat
			if (count scopeRows) is 1 then
				set scopeRow to contents of item 1 of scopeRows
				select scopeRow
			else
				select scopeRows
			end if
		end if
	end tell
	-- Selecting a scope changes Mail's window title. Verify through fresh
	-- references instead of reading the rows tied to the old title.
	repeat 30 times
		try
			if my captureMailboxScope() is originalScope then return
		on error scopeError number scopeNumber
			if scopeNumber is -1743 or scopeNumber is -25211 or scopeNumber is -1712 then error scopeError number scopeNumber
		end try
		delay 0.1
	end repeat
	error "Could not confirm the selected mailbox scope. Review the sidebar before using the results."
end restoreMailboxScope

on focusMailSearchField()
	-- Use Mail's own Mailbox Search command. Do not set AXFocused on a
	-- toolbar reference: Mail can invalidate it when the filter/title changes.
	tell application "System Events" to tell process "Mail"
		if not frontmost then error "Mail lost focus. Run the shortcut again in Mail."
		if exists menu bar item "Bearbeiten" of menu bar 1 then
			set editMenuItem to menu bar item "Bearbeiten" of menu bar 1
			set findMenuName to "Suchen"
		else
			set editMenuItem to menu bar item "Edit" of menu bar 1
			set findMenuName to "Find"
		end if
		set searchCommands to menu items of menu 1 of menu item findMenuName of menu 1 of editMenuItem
		set mailboxSearchCommand to missing value
		repeat with searchCommand in searchCommands
			if value of attribute "AXIdentifier" of searchCommand is "Mail.menuBar.editMenu.find.mailboxSearch" then set mailboxSearchCommand to contents of searchCommand
		end repeat
		if mailboxSearchCommand is missing value then error "Mail's Mailbox Search menu command is unavailable."
		click editMenuItem
		click mailboxSearchCommand
	end tell
	repeat 30 times
		tell application "System Events" to tell process "Mail"
			if not frontmost then error "Mail lost focus. Run the shortcut again in Mail."
		end tell
		try
			set freshSearchField to my mailSearchField()
			tell application "System Events"
				if value of attribute "AXFocused" of freshSearchField then return
			end tell
		on error focusError number focusNumber
			if focusNumber is -1743 or focusNumber is -25211 or focusNumber is -1712 then error focusError number focusNumber
		end try
		delay 0.1
	end repeat
	error "Could not focus Mail's mailbox search field. Run the shortcut again."
end focusMailSearchField

on mailViewerWindow()
	tell application "System Events" to tell process "Mail"
		if not frontmost then error "Mail lost focus. Run the shortcut again in Mail."
		repeat with candidateWindow in windows
			try
				set windowID to value of attribute "AXIdentifier" of candidateWindow
				if windowID starts with "Mail.messageViewer.window." then return contents of candidateWindow
			end try
		end repeat
	end tell
	error "Open Mail's message-list window and close any Mail dialog, then try again."
end mailViewerWindow

on mailSearchField()
	repeat 30 times
		tell application "System Events" to tell process "Mail"
			if not frontmost then error "Mail lost focus. Run the shortcut again in Mail."
		end tell
		try
			set viewerWindow to my mailViewerWindow()
			tell application "System Events"
				set toolbarElements to entire contents of toolbar 1 of viewerWindow
				repeat with fieldElement in toolbarElements
					if subrole of fieldElement is "AXSearchField" then return contents of fieldElement
				end repeat
			end tell
		on error fieldError number fieldNumber
			if fieldNumber is -1743 or fieldNumber is -25211 or fieldNumber is -1712 then error fieldError number fieldNumber
		end try
		delay 0.1
	end repeat
	error "Mail's search toolbar is not ready. Close any Mail dialog, show the message-list toolbar, and try again."
end mailSearchField

on disableMessageFilter()
	repeat 30 times
		try
			set viewerWindow to my mailViewerWindow()
			tell application "System Events"
				set filterControls to checkboxes of toolbar 1 of viewerWindow
				repeat with filterControl in filterControls
					if description of filterControl is "Filter" and value of filterControl is 1 then
						click filterControl
						exit repeat
					end if
				end repeat
			end tell
			return
		on error filterError number filterNumber
			if filterNumber is -1743 or filterNumber is -25211 or filterNumber is -1712 then error filterError number filterNumber
		end try
		delay 0.1
	end repeat
	error "Mail's message filter is not ready. Close any Mail dialog and try again."
end disableMessageFilter

on waitForModifierRelease()
	-- Bits 17 through 20 are Shift, Control, Option, and Command. Never type
	-- while the physical shortcut modifiers remain down.
	repeat 100 times
		set modifierFlags to (current application's NSEvent's modifierFlags()) as integer
		if (modifierFlags div 131072) mod 16 is 0 then return
		delay 0.05
	end repeat
	error "Release Control, Option, Command, and Shift, then run the shortcut again."
end waitForModifierRelease

on restorePasteboard(pasteboard, savedItems, ourChangeCount)
	-- Do not overwrite something the user copied while the search was running.
	if (pasteboard's changeCount() as integer) is ourChangeCount then
		pasteboard's clearContents()
		if (savedItems's |count|() as integer) > 0 then pasteboard's writeObjects:savedItems
	end if
end restorePasteboard

on pasteSearchQuery(queryText)
	my waitForModifierRelease()
	my focusMailSearchField()
	set pasteboard to current application's NSPasteboard's generalPasteboard()
	set savedItems to current application's NSMutableArray's array()
	set originalItems to pasteboard's pasteboardItems()
	repeat with i from 0 to (originalItems's |count|() as integer) - 1
		set originalItem to originalItems's objectAtIndex:i
		set savedItem to current application's NSPasteboardItem's alloc()'s init()
		set itemTypes to originalItem's types()
		repeat with j from 0 to (itemTypes's |count|() as integer) - 1
			set itemType to itemTypes's objectAtIndex:j
			set itemData to originalItem's dataForType:itemType
			if itemData is not missing value then savedItem's setData:itemData forType:itemType
		end repeat
		savedItems's addObject:savedItem
	end repeat
	pasteboard's clearContents()
	pasteboard's setString:queryText forType:(current application's NSPasteboardTypeString)
	set ourChangeCount to pasteboard's changeCount() as integer
	try
		my waitForModifierRelease()
		set searchField to my mailSearchField()
		tell application "System Events"
			if not (value of attribute "AXFocused" of searchField) then error "Mail's search field lost focus. Run the shortcut again."
		end tell
		tell application "System Events" to tell process "Mail"
			keystroke "a" using command down
			keystroke "v" using command down
		end tell
		set queryVerified to false
		repeat 30 times
			set searchField to my mailSearchField()
			tell application "System Events" to set actualQuery to value of searchField as text
			if actualQuery is queryText then
				set queryVerified to true
				exit repeat
			end if
			delay 0.1
		end repeat
		if not queryVerified then error "Mail did not receive the expected search text. No search was submitted."
		my waitForModifierRelease()
		tell application "System Events" to tell process "Mail"
			if not frontmost then error "Mail lost focus. Run the shortcut again in Mail."
			keystroke return
		end tell
	on error pasteError number pasteNumber
		my restorePasteboard(pasteboard, savedItems, ourChangeCount)
		error pasteError number pasteNumber
	end try
	my restorePasteboard(pasteboard, savedItems, ourChangeCount)
end pasteSearchQuery
