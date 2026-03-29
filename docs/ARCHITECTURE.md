# Architecture

The structure in general will be a mix of vertical slice architecture as defined [here](https://ddd-practitioners.com/home/glossary/vertical-slice-architecture/), where each slice is a feature as defined in @docs/PRODUCT_SPEC.md.

Each vertical slice would have three layers: domain, data and UI.

## Domain
Domain is where all the domain related classes are stored. NO classes from data, UI or infrastructure layers must be here:
  - The core domain is a habit tracking, which includes habits, pacts, showups and timelines.
  - The colors or emoji assignment to the habits is a support domain
  - Preparing notifications are also a support domain.

## Data
All the data management related classes are located in data layer.
- Storage and mapping data to the domain layer and back are located in data layer.
- Changes in the data layer (schemes, contracts etc.) should also be covered with tests in order to prevent issues during migrations. If change in schemes or APIs occur, the migration files should be generated and tested.

## UI
All the UI related classes are located in the UI layer. 
- Custom widgets and mapping from Domain to the UI and back belong here.
- There should be three sublayers: for iOS (Cupertino), for Android (Material), and a generic one that prepares the view state and delegates rendering to the platform-specific sublayer.
- The class where `runApp` is getting called should be out of this hierarchy (`lib/main.dart`).

## Flutter-related details
- [sqflite](https://pub.dev/packages/sqflite) for local storage.
- [Riverpod](https://riverpod.dev/) for state management and dependency injection.