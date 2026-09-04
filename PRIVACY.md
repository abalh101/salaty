# SalahFocus Privacy Summary

SalahFocus is designed as a local-first prayer companion.

## Stored on the device

The app stores prayer history, cached prayer times, focus state, settings, selected location and user preferences locally on the device.

## Network use

Network access is used to retrieve prayer calendars from the configured prayer-time provider. The provider receives the selected latitude/longitude and calculation options needed to return prayer times. When the user manually searches for a city, the operating system's geocoding service may also use network access.

The current MVP does not operate a SalahFocus account server and does not upload prayer history to a SalahFocus backend.

## Analytics and advertising

The MVP contains no advertising SDK and no prayer-behavior analytics SDK.

## Location

Location access is requested only after the user chooses automatic location. Permanent background location is not requested. The user can instead choose a city manually.

## Religious data

Prayer confirmations and prayer history are treated as private local data. They are not sold and are not used for advertising.

## Future cloud features

Any future account, backup or synchronization feature must be opt-in and documented separately before release.
