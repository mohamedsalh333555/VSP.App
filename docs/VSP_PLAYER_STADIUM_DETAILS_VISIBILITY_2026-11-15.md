# Player venue information from owner payload — 21.05

A widget test builds the owner wizard's feature payload, gives it to the real player information tab and booking price bar, then checks the venue name, Aswan location, enabled Cafeteria/Changing Rooms/Seats, hidden Garage, ball rental and hourly/deposit prices. This confirms that these owner-provided values are rendered in the player components. [Flutter CI 43668494949](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43668494949) runs the test with the full suite.

The fixture is synthetic. A live owner edit, database propagation, a second player account and venue publication/availability require separate end-to-end verification; this test does not establish those outcomes.
