# 🚨 IMPORTANT: READ THIS ENTIRE FILE FIRST 🚨

Before responding to ANY request, fully review this CLAUDE.md file. All project
architecture, standards, and conventions are defined here. Reference these rules
in every response.

---

# Flutter - Claude Code Context

## General Overview

This is a Flutter application following Clean Architecture principles with
BLoC/Cubit for state management (and Supabase with Edge Functions, if specified in `pubspec.yaml`). The project uses Dart 3 features and maintains
strict separation of concerns across presentation, domain, and data layers.

---

## Architecture & Core Principles

### Clean Architecture

- Follow layered architecture: Presentation → Domain → Data
- Feature-first folder structure:
  `lib/features/[feature_name]/{data,domain,presentation}`
- Dependencies point inward: presentation depends on domain, domain has no
  dependencies on outer layers
- Keep business logic in domain layer, UI logic in presentation, infrastructure
  in data

### State Management (BLoC/Cubit)

- Use BLoC/Cubit patterns exclusively for state management
- Always use sealed classes for BLoC states to enforce exhaustive handling
- State types: Loading, Success, Error (minimum)
- Keep ALL business logic in BLoC/Cubit - widgets should be purely
  presentational
- **BlocBuilder or BlocSelector**: for single state dependencies and rebuilding
  UI
- **BlocListener**: for side effects (navigation, snackbars, dialogs)
- **BlocConsumer**: when you need both listening and building
- Event/method naming conventions:
  - Events: past tense nouns (e.g., `LoginRequested`, `UserDataFetched`)
  - Cubit methods: present tense verbs (e.g., `login()`, `fetchUserData()`)
- Always dispose controllers and subscriptions in `close()` method

---

## Code Organization & Structure

### File Organization

- File naming: `snake_case` for all Dart files (e.g.,
  `user_profile_screen.dart`)
- One public widget per file - name file after the widget
- Feature structure:

```
lib/core/
lib/features/feature_name/
  ├── data/
  │   ├── datasources/     # remote_data_source.dart, local_data_source.dart
  │   ├── models/          # DTOs with fromJson/toJson
  │   └── repositories/    # repository implementations
  ├── domain/
  │   ├── entities/        # business objects
  │   ├── repositories/    # abstract repository interfaces
  │   └── usecases/        # business logic operations
  └── presentation/
      ├── bloc/            # BLoC + states + events
      ├── cubit/           # Cubit + states
      ├── pages/           # full screens
      └── widgets/         # reusable components
```

### Import Organization

Group imports in this order (with blank lines between groups):

1. Dart SDK imports (`dart:...`)
2. Flutter SDK imports (`package:flutter/...`)
3. Third-party package imports (`package:...`)
4. Avoid relative imports (`../...` or local files)

### Barrel Files

- Use `index.dart` barrel files sparingly
- Only for public APIs that are consumed by other features
- Avoid for internal feature organization

---

## Data Layer

### Repository Pattern

- Abstract repositories in domain layer define contracts
- Concrete implementations in data layer
- Use `Either<Failure, Success>` or `Result<Success, Failure>` type for error
  handling
- Always handle exceptions in data layer, never let them bubble to
  domain/presentation
- Return domain-level `Failure` objects, not exceptions

### Data Sources

- Separate remote and local data sources clearly
- Remote: API calls, network operations
- Local: SharedPreferences, Hive/Drift, SQLite, cache
- Use dependency injection for data sources in repository implementations

### Models vs Entities

- **Entities** (domain): pure business objects, no serialization
- **DTOs/Models** (data): JSON serialization, API contracts
- Always map between DTOs and Entities at repository boundary
- Use `freezed` or code generation for models (if specified in `pubspec.yaml`)

### API/Network Layer

- Use `dio` or `http` package (if specified in `pubspec.yaml`)
- Create typed API response models for all endpoints
- Handle timeouts (default: 30 seconds) and connectivity issues
- Implement request/response interceptors for logging
- Model generation: `json_serializable` or `freezed` (if specified in
  `pubspec.yaml`)

---

## Presentation Layer

### Widget Patterns

- **Private widget methods**: Prefer private `_MyStatelessOrStatefulWidget()`
  over inline build logic or build methods like `Widget _buildMyWidget()`
- **Extraction threshold**: Extract to separate widget when:
  - More than 50 lines
  - Reused in multiple places
  - Needs const optimization
- Use named constructors for widget variations (e.g., `MyButton.large()`,
  `MyButton.icon()`)
- Always use `Key` for widgets in dynamic lists or reorderable collections

### Callbacks & Functions

- Prefer `VoidCallback` over `Function()` for parameter-less callbacks
- Prefer `ValueChanged<T>` over `Function(T)` for single-parameter callbacks
- Define callback types for complex signatures

### UI Components

- **GestureDetector** over InkWell (preferred for custom interactions)
- **Spacing**: Use `mainAxisAlignment` and `spacing` parameter on Column/Row
  (Dart 3) instead of SizedBox
- Avoid deeply nested widget trees (max 3-4 levels) - extract to methods or
  widgets
- Access theme via `Theme.of(context)` - never hardcode colors, sizes, or text
  styles
- Strictly use `wolt_modal_sheet` for bottom sheet implementations
- Incorporate `flutter_animate` (if specified in `pubspec.yaml`) and `HapticFeedback` for smooth UX

### BuildContext Safety

- Never use `BuildContext` across async gaps without checking `mounted`
- Pattern for safe async usage:

```dart
await someAsyncOperation();
if (!mounted) return;
// safe to use context here
```

### Responsive Design

- Use `MediaQuery.of(context)` for screen dimensions
- Use `LayoutBuilder` for adaptive layouts based on available space
- Consider breakpoints for different device sizes

---

## Error Handling

### Error Flow

- **Presentation Layer**: NO try-catch blocks - handle errors in BLoC/Cubit
  states
- **Domain Layer**: Define business logic errors as domain failures
- **Data Layer**: Catch ALL exceptions, convert to domain `Failure` objects

### Failure Classes

- Create custom `Failure` classes in domain layer:

```dart
sealed class Failure {}
class NetworkFailure extends Failure {}
class ServerFailure extends Failure {}
class CacheFailure extends Failure {}
```

- Always provide user-friendly error messages in presentation layer
- Log errors with context: stack traces in debug mode, sanitized logs in
  production

---

## Dependency Injection

- Use `get_it`, `injectable` package (if specified in `pubspec.yaml`)
- Register all dependencies at app startup (main.dart or setup function)
- Use **constructor injection** - avoid service locators in widgets
- Make dependencies mockable for testing

---

## Testing Requirements (only respect if if minimum coverage not 0%)

- not yet specified

### Test Coverage

- Minimum coverage target: 0%
- Required tests:
  - **BLoC tests**: verify all state transitions and event handling
  - **Repository tests**: mock data sources, verify mapping
  - **Widget tests**: user interactions, state-driven UI changes
  - **UseCase tests** (if applicable)

### Testing Patterns

- Mock ALL external dependencies (repositories, APIs, data sources)
- Use `blocTest` package for BLoC/Cubit testing
- Widget testing: appropriate use of `pump()` vs `pumpAndSettle()`
- Never test implementation details - test behavior and outcomes

---

## Widgets & UI Best Practices

### Performance & Const

- **Always use `const` constructors** wherever possible
- Mark widget constructors as `const` when all parameters are final
- Split large build methods into smaller const widgets
- Use `const` for all static content (Text, Padding, SizedBox, etc.)

### Performance Optimization

- Use `RepaintBoundary` for complex, rarely-changing sections
- Avoid anonymous functions in build methods:

```dart
// BAD
onPressed: () => doSomething()

// GOOD
onPressed: _handlePress
```

- For long lists: ALWAYS use `.builder` constructors:
  - `ListView.builder` not `ListView(children: list.map...)`
  - `GridView.builder` not `GridView(children: ...)`

### Widget Lifecycle

- Override `dispose()` to clean up controllers, listeners, subscriptions
- Initialize controllers in `initState()`, never in build method
- For StatefulWidgets with async: always check `mounted` before setState

---

## Null Safety & Dart 3 Features

### Null Safety

- Prefer null-aware operators over explicit null checks:
  - `??` for default values
  - `?.` for safe property access
  - `?..` for safe cascades
- **Avoid `!` operator** unless absolutely certain value is non-null
- When uncertain, use explicit null checks with early returns
- Use `late` keyword for non-nullable fields initialized outside constructor
- Pattern: return early on null rather than deeply nesting code

### Dart 3 Specific Features

- Use **records** for multiple return values: `(String, int)` not custom classes
- Use **patterns** and **pattern matching** in switch expressions
- Use **if-case** for type checking with destructuring
- Prefer **sealed classes** over enums when you need associated data
- Use **class modifiers** appropriately: `final`, `base`, `interface`, `sealed`

---

## Code Quality & Standards

### Static Analysis

- Run `flutter analyze` before every commit - fix ALL warnings
- Run `dart fix --apply` to auto-fix lints where possible
- Format all code with `dart format` before committing

### Documentation

- Use doc comments (`///`) for all public APIs, classes, and methods
- Add meaningful TODO comments with context:
  `// TODO(#123): Refactor this to use new API`
- Complex logic: explain WHY, not WHAT (code shows what)

### Constants & Magic Numbers

- No magic numbers - use named constants
- Define constants at class level or in dedicated constants file
- Use ALL_CAPS for compile-time constants

### Logging

- Never use `print()` - use a logging package like `logger` or `loggy` (if
  specified in `pubspec.yaml`) or implement a reasonable logger util first
- Log levels: debug, info, warning, error
- Include context in error logs

---

## Common Flutter Patterns

### Extensions

- Use extension methods for common context shortcuts:

```dart
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(context);
  TextTheme get textTheme => Theme.of(context).textTheme;
}
```

### Immutability

- Implement `copyWith()` for all immutable data classes
- Override `==` and `hashCode` for value objects
- Use `@immutable` annotation on immutable classes

### JSON Parsing

- Use factory constructors for `fromJson`
- Implement `toJson()` method for serialization
- [If using code generation]: Run build_runner after model changes

---

## Things to AVOID

### Prohibited Patterns

- ❌ Never use `setState` in StatelessWidget
- ❌ Never put business logic in widgets
- ❌ Never use global state or singletons (except DI container)
- ❌ Never ignore BuildContext lifecycle in async operations
- ❌ Never use `print()` for logging
- ❌ Never hardcode strings - use localization from the start
- ❌ Never use `!` operator without being 100% certain
- ❌ Never use `FutureBuilder`/`StreamBuilder` when BLoC/Cubit is appropriate
- ❌ Never nest widgets more than 3-4 levels without extracting
- ❌ Never use `.map()` to build large lists - use `.builder()`

---

## Assets & Localization (Skip this)

- Use `flutter_gen` package for assets (if specified in `pubspec.yaml`)
- Use `easy_localization`, `intl` or `slang` package for i18n/l10n (if specified
  in `pubspec.yaml`)
- Never hardcode strings - always use localization keys
- Asset references: use generated constants, never string literals
- Keep all user-facing text in localization files from day one

---

## Navigation

- Use `go_router` package or `Navigator 2.0` (if specified in `pubspec.yaml`)
- Keep navigation logic OUT of BLoC/Cubit
- Use named routes consistently throughout app
- [If using go_router]: Define routes in centralized router file

---

## Supabase & Edge Functions

### Client Setup

- Always use a singleton Supabase client — never instantiate multiple clients
- Initialize in `main.dart` before `runApp()` and register via DI container
- Use separate clients for public (anon key) vs admin operations — never expose
  `service_role` key on the client side
- Use `supabase_flutter` package for Flutter; raw `supabase` for Edge Functions
```dart
// core/supabase/supabase_client.dart
final supabase = Supabase.instance.client;
```

### Auth

- Always listen to `supabase.auth.onAuthStateChange` stream via a top-level
  AuthCubit/BLoC — never poll auth state
- Persist session automatically via `Supabase.initialize(...)` — do NOT manage
  tokens manually
- Use Row Level Security (RLS) on ALL tables — never rely solely on client-side
  guards
- Redirect deep links for OAuth/magic link through `go_router` — define the
  redirect URI in Supabase dashboard AND app router
- Always sign out on unrecoverable auth errors (expired refresh token, banned user)
```dart
supabase.auth.onAuthStateChange.listen((data) {
  final event = data.event;
  // Handle AuthChangeEvent in AuthCubit
});
```

### Database & Realtime

- Use typed response models — always `.select()` with explicit column lists,
  never `select('*')` in production
- Map Supabase responses to domain Entities at the repository boundary
- Use `.maybeSingle()` instead of `.single()` when a result may be absent —
  `.single()` throws on empty
- Wrap all Supabase calls in try-catch inside the data source layer; convert
  `PostgrestException` / `AuthException` to domain `Failure` objects
- For Realtime subscriptions: subscribe in data source, expose as `Stream` to
  repository, clean up channel in `close()` / `dispose()`
```dart
// data/datasources/messages_remote_data_source.dart
Stream<List<MessageModel>> watchMessages(String roomId) {
  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .map((rows) => rows.map(MessageModel.fromJson).toList());
}
```

### Storage

- Always use signed URLs for private buckets — never expose bucket paths directly
- Set MIME type and file size limits in bucket policies, not just client-side
- Generate a unique file path using UUID or user ID prefix to avoid collisions:
  `'${userId}/${const Uuid().v4()}.jpg'`
- Delete old files explicitly when replacing (Supabase does not auto-overwrite
  by default without `upsert: true`)
```dart
final path = '${userId}/${const Uuid().v4()}.jpg';
await supabase.storage.from('avatars').uploadBinary(
  path,
  bytes,
  fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
);
```

### Edge Functions

#### Structure & Conventions

- One function per responsibility — avoid monolithic Edge Functions
- Name functions in `kebab-case` matching their route: `send-notification`,
  `create-checkout-session`
- Keep shared logic in `supabase/functions/_shared/` and import across functions
- Always version your function signatures if breaking changes are possible
```
supabase/functions/
  ├── _shared/
  │   ├── cors.ts          # shared CORS headers
  │   ├── supabase.ts      # admin client factory
  │   └── errors.ts        # typed error responses
  ├── send-notification/
  │   └── index.ts
  └── create-checkout-session/
      └── index.ts
```

#### CORS

- Define CORS headers once in `_shared/cors.ts` — never inline them per function
- Always handle `OPTIONS` preflight requests and return `200` immediately
```ts
// _shared/cors.ts
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // restrict in production
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

// index.ts
if (req.method === 'OPTIONS') {
  return new Response('ok', { headers: corsHeaders });
}
```

#### Auth Verification

- ALWAYS verify the JWT from the `Authorization` header server-side — never
  trust client-supplied user IDs
- Use the Supabase admin client (service role) only inside Edge Functions, never
  on the Flutter client
```ts
// _shared/supabase.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const createAdminClient = () =>
  createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

export const getUserFromRequest = async (req: Request) => {
  const token = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (!token) throw new Error('Missing auth token');

  const supabase = createAdminClient();
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) throw new Error('Unauthorized');
  return user;
};
```

#### Input Validation & Error Handling

- Validate ALL inputs — treat every incoming request as untrusted
- Return consistent typed JSON error responses with appropriate HTTP status codes
- Never leak internal error details (stack traces, DB errors) to the client
```ts
// _shared/errors.ts
export const errorResponse = (message: string, status = 400) =>
  new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });

// index.ts
try {
  const user = await getUserFromRequest(req);
  const body = await req.json();

  if (!body.targetId) return errorResponse('targetId is required');

  // ... logic
} catch (e) {
  if (e.message === 'Unauthorized') return errorResponse('Unauthorized', 401);
  return errorResponse('Internal server error', 500);
}
```

#### Calling Edge Functions from Flutter

- Call via `supabase.functions.invoke()` — never construct the URL manually
- Handle `FunctionsException` separately from generic exceptions in the data source
- Pass auth token automatically — the Flutter SDK handles the `Authorization`
  header when using `invoke()`
```dart
// data/datasources/notification_remote_data_source.dart
Future<void> sendNotification(String targetId) async {
  try {
    await supabase.functions.invoke(
      'send-notification',
      body: {'targetId': targetId},
    );
  } on FunctionsException catch (e) {
    throw ServerFailure(e.details?.toString() ?? e.message);
  } catch (_) {
    throw const NetworkFailure();
  }
}
```

#### Secrets & Environment Variables

- Store ALL secrets in Supabase Vault or via `supabase secrets set` — never
  hardcode in function source
- Access secrets via `Deno.env.get('SECRET_NAME')` — assert non-null at startup
  so the function fails fast on misconfiguration
- Never log secret values — sanitize all logs in Edge Functions

#### Performance & Limits

- Keep Edge Functions stateless — no in-memory caches that persist across invocations
- Respond within 2 seconds for user-facing calls; use background tasks or
  Supabase Queues for heavy work
- Avoid chaining multiple round-trips inside a single Edge Function — use
  Postgres functions (RPC) to batch DB operations
- Use `supabase.rpc()` for complex DB logic rather than multiple sequential
  `.from().select()` calls

---

## Common Commands

### Development

```bash
# Install dependencies
flutter pub get

# Code generation (if using freezed/json_serializable/build_runner etc.)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
flutter pub run build_runner watch --delete-conflicting-outputs

# Static analysis
flutter analyze

# Auto-fix lints
dart fix --apply

# Format code
dart format lib/ test/
```

### Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/auth/auth_bloc_test.dart

# View coverage report (after generating)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Build

- not yet specified

---

## Project-Specific Notes

- iOS only and optimized (UI/UX iOS first)

### Project Domain

- Agnostic pose detection demo app using `google_mlkit_pose_detection`

---

## Code Review Checklist

When reviewing generated code, ensure:

- [ ] All classes/methods follow naming conventions
- [ ] No business logic in widgets
- [ ] All public APIs have doc comments
- [ ] Error handling is at correct layer
- [ ] Tests are included for new features
- [ ] No magic numbers or hardcoded strings
- [ ] Const constructors used where possible
- [ ] No ignored linter warnings without justification
