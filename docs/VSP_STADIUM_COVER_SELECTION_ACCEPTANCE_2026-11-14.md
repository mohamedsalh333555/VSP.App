# Stadium cover selection — 20.03

The owner gallery now labels its first saved photo as the cover and provides “Set as cover” for other uploaded photos. Choosing a different photo moves it to the front of the image list, persists that order in an unsaved stadium draft and triggers an immediate screen update. Both stadium creation and editing derive the primary `imageUrl` from the first uploaded URL, so the selection feeds their existing payload without introducing a parallel cover field.

The widget test selects the second photo, reads the saved draft and asserts the update payload uses the selected cover URL. The same reorder path is used by new and edited stadiums. [Flutter CI 43644752625](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43644752625) runs this test and the full suite. It does not establish live storage persistence or rendering in a player's client; those cross-account checks remain open.
