on run {input, parameters}
    set scriptFile to (path to library folder from user domain as text) & "Scripts:Mail:FindEmailsFromSender.scpt"
    run script alias scriptFile
    return
end run
