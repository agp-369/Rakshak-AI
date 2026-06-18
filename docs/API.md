# API Reference

## GemmaInferenceService

Core LLM inference wrapper.

### `Future<bool> initialize()`

Loads the model from device storage. Returns `true` on success.

### `Future<String> generate(String prompt, {int maxTokens, double temperature})`

Runs inference and returns generated text. Token limit and temperature are configurable. Uses GPU backend when available, CPU fallback otherwise.

### `Future<({String label, double confidence})> analyzeImage(String imagePath, String prompt)`

Processes an image through the vision model. Only available on GPU-capable devices. Returns a label and confidence score.

### `Future<({bool hasGpu, int ramMb})> detectCapabilities()`

Probes device for GPU availability and total RAM. Used to select appropriate inference settings.

## GemmaTriageService

Builds structured prompts for medical triage and parses LLM responses.

### `Future<TriageResult> parseAndAssess(String description, {String language})`

Sends a patient description to the LLM. Accepts Hindi or English input. Returns a `TriageResult` with:

| Field | Type | Description |
|-------|------|-------------|
| `category` | `String` | START triage category: `RED`, `YELLOW`, `GREEN`, `BLACK` |
| `confidence` | `String` | `high`, `medium`, `low`, `insufficient` |
| `summary` | `String` | Brief explanation in the input language |
| `source` | `String` | `llm` or `fallback` |

### Prompt template

```
You are a disaster medical triage assistant for India.
Assess the following patient and return JSON:
{
  "category": "RED|YELLOW|GREEN|BLACK",
  "reason": "Brief explanation",
  "vitals": { ... }
}
Patient: {description}
```

### Fallback parsing

If the LLM returns malformed JSON, `parseAndAssess` falls back to `TriageEngine.parseFromDescription()` which uses regex patterns to extract vital signs from the text.

## TriageEngine

START protocol decision engine.

### `TriageResult assess(TriageVitals vitals)`

| Parameter | Type | Description |
|-----------|------|-------------|
| `vitals.isWalking` | `bool` | Patient walking unassisted |
| `vitals.isBreathing` | `bool` | Patient breathing |
| `vitals.respiratoryRate` | `int?` | Breaths per minute |
| `vitals.hasRadialPulse` | `bool` | Radial pulse palpable |
| `vitals.capillaryRefill` | `int?` | Capillary refill in seconds |
| `vitals.isResponsive` | `bool` | Responds to stimuli |

Decision tree output:

| Condition | Category |
|-----------|----------|
| Walking unassisted | GREEN |
| Not breathing after airway | BLACK |
| RR > 30 or RR < 10 | RED |
| No radial pulse | RED |
| Cap refill > 2s | RED |
| Unresponsive | RED |
| Otherwise | YELLOW |

## GpsService

### `Future<Position> getCurrentPosition()`

Returns device location. Uses cached last-known position if GPS is unavailable.

### `double calculateDistance(double lat1, double lon1, double lat2, double lon2)`

Haversine distance in meters between two coordinates.

## MeshService

### `String generateSyncPayload()`

Serializes all patient records to a GZip + Base64 encoded string suitable for QR code encoding.

### `Future<int> processSyncPayload(String payload)`

Decodes an incoming payload, deserializes patient records, and merges into the local database. Returns count of new/updated patients.

### `void showSyncQrCode(BuildContext context)`

Renders the sync payload as a QR code in a dialog. The recipient scans with `processSyncPayload`.

## PatientRepository

### `Future<int> insert(PatientRecord record)`

Persists a triage record. Returns the row ID.

### `Future<List<PatientRecord>> getAll()`

Returns all records ordered by timestamp descending.

### `Future<Map<String, int>> getCategoryCounts()`

Returns count of patients per triage category (`RED`, `YELLOW`, `GREEN`, `BLACK`).

### `Future<void> delete(int id)`

Removes a record by ID.

## DeviceCapabilities

Returned by `GemmaInferenceService.detectCapabilities()`.

| Field | Type | Description |
|-------|------|-------------|
| `hasGpu` | `bool` | GPU accelerator available |
| `ramMb` | `int` | Total device RAM in MB |

Adjusts inference behavior:
- **RAM < 4096 MB**: `maxTokens` limited to 512, CPU backend forced
- **RAM >= 4096 MB + GPU**: `maxTokens` set to 1024, GPU backend enabled, vision features available

## START Triage Categories

| Color | Priority | Meaning |
|-------|----------|---------|
| RED | Immediate | Life-threatening, needs treatment within minutes |
| YELLOW | Delayed | Serious but stable, can wait up to 1 hour |
| GREEN | Minor | Walking wounded, can self-evacuate |
| BLACK | Deceased | No breathing after airway intervention |
