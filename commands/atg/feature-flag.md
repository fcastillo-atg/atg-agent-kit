---
description: Generate a single-file feature flag (interface + Noop + Enabled + ProxyFactory) and wire it into the service
---

# Feature Flag Implementation

You are a Spring Boot feature flag expert specializing in Trunk-Based Development patterns. Create production-ready feature flags following the consolidated single-file pattern established in this codebase.

## Context
The user needs to wrap new functionality behind a feature flag for safe rollout in Trunk-Based Development. All feature flag components (interface, implementations, factory) must be in a **single file** for easy cleanup when the feature is stable.

**Feature Flag Control:** Feature flags are controlled via cookies in endpoint calls, not environment variables. This allows:
- Real-time feature toggling without restarts
- Per-request feature flag state
- Easy testing in production with specific cookies
- No need to update `env.template` or redeploy

**Feature Flag Naming:** The system automatically adds `FF_` prefix to feature flag names.
- You define: `@Feature("feature_name")`
- Cookie uses: `FF_feature_name=true`
- Example: `@Feature("auction_propagation")` → Cookie: `FF_auction_propagation=true`

## Requirements
$ARGUMENTS

## Pattern Reference
This codebase uses a consolidated pattern where all feature flag components live in one file:
- See `src/main/kotlin/com/sellerportal/api/lotimport/LotSequenceAssignmentFeatureFlag.kt` for reference implementation
- See `src/main/kotlin/com/atg/featureflag/FeatureFlags.kt` for base infrastructure

## Instructions

### 1. Analyze Requirements and Existing Code

**Extract Information:**
```kotlin
// Identify:
// 1. Feature name (snake_case): e.g., "batch_validation", "sequence_assignment"
// 2. Target functionality to wrap
// 3. Interface name and methods needed
// 4. Enabled implementation name (descriptive, not just "EnabledXxx")
// 5. Current service/operation signatures
// 6. Test fixtures that need updating
```

**Naming Conventions:**
- **Feature Flag**: `{feature_name}` (snake_case in annotation)
- **Interface**: `{DomainConcept}` (e.g., `BatchValidator`, `SequenceAssigner`)
- **Noop Implementation**: `Noop{InterfaceName}` (always this pattern)
- **Enabled Implementation**: Descriptive name based on complexity:
  - Simple delegation: `Enabled{InterfaceName}`
  - Complex logic: `Composite{InterfaceName}`, `Full{InterfaceName}`, `{Adjective}{InterfaceName}`
- **Factory**: `{InterfaceName}ProxyFactory` (always this pattern)
- **File Name**: `{InterfaceName}FeatureFlag.kt` or `{FeatureDescription}FeatureFlag.kt`

### 2. Create Feature Flag File (Single Consolidated File)

**File Location:** `src/main/kotlin/com/{package}/{DescriptiveName}FeatureFlag.kt`

**Examples:**
- `LotSequenceAssignmentFeatureFlag.kt`
- `LotBatchValidationFeatureFlag.kt`
- `AuctionAddressInheritanceFeatureFlag.kt`

**Template Structure:**
```kotlin
package com.{package}

import com.atg.KoverIgnore
import com.atg.featureflag.Feature
import com.atg.featureflag.FeatureFlagProvider
import com.atg.featureflag.FeatureProxyFactory
import org.springframework.context.annotation.Primary
import org.springframework.stereotype.Component

/**
 * Feature flag wrapper for {feature description}.
 *
 * Controlled by the "{feature_flag_name}" feature flag:
 * - **Enabled**: {describe new behavior}
 * - **Disabled**: {describe legacy behavior}
 *
 * All components are defined in this single file for easier cleanup when the feature flag is removed.
 */

@Feature("{feature_flag_name}")
interface {InterfaceName} {
    fun {methodName}({params}): {ReturnType}
    // Add all required methods
}

@Component
class Noop{InterfaceName} : {InterfaceName} {
    // Legacy behavior - return data unchanged or skip processing
    override fun {methodName}({params}): {ReturnType} = {legacyBehavior}
}

@Component
class {EnabledImplementationName} : {InterfaceName} {
    // New behavior - can be simple delegation or complex logic
    override fun {methodName}({params}): {ReturnType} {
        // Implementation here
    }
}

@Primary
@Component
@KoverIgnore("FeatureProxyFactory has tests")
class {InterfaceName}ProxyFactory(
    featureFlagProviders: List<FeatureFlagProvider>,
    enabledImplementation: {EnabledImplementationName},
    disabledImplementation: Noop{InterfaceName},
) : FeatureProxyFactory<{InterfaceName}>(
    {InterfaceName}::class,
    featureFlagProviders,
    enabledImplementation,
    disabledImplementation
)
```

**Key Principles:**
1. **Single File**: All components (interface, implementations, factory) in one file
2. **Noop Implementation**: Always returns empty/unchanged data for legacy behavior
3. **Enabled Implementation Naming**: Use descriptive names (e.g., `CompositeLotBatchDataValidator`, `EnabledLotSequenceAssigner`) based on complexity
4. **ExpressionBodySyntax**: Use `= expression` for single-statement methods (Detekt requirement)
5. **@KoverIgnore**: Always add to ProxyFactory (infrastructure already tested)
6. **Factory Parameter Order**: `enabledImplementation` before `disabledImplementation`

### 3. Update Service Dependencies

**Inject Feature Flag Interface:**
```kotlin
class SomeService(
    // ... existing dependencies
    private val validator: BatchValidator, // NEW - inject interface, not implementation
) {
    fun someOperation() {
        // Replace direct call:
        // val result = SomeOperation.doSomething(data)

        // With feature flag interface call:
        val result = validator.validate(data)
    }
}
```

**Important:** Always inject the **interface**, not the concrete implementation. Spring will automatically wire the ProxyFactory.

**Method Signature Updates (if needed):**
```kotlin
// If wrapping an existing operation, may need to:
// 1. Add parameter to accept feature flag interface
// 2. Change visibility (private -> internal) if delegating
// 3. Use named arguments if >3 parameters (Detekt requirement)
```

### 4. Update Test Fixtures

**For Unit Tests:**
```groovy
// SomeServiceSpec.groovy example
class SomeServiceSpec extends Specification {

    // Use concrete implementation - typically enabled for testing new behavior
    private final BatchValidator validator = new CompositeBatchValidator()

    // Or use noop for testing legacy behavior
    // private final BatchValidator validator = new NoopBatchValidator()

    private final SomeService service = new SomeService(
        // ... other mocks
        validator, // NEW
    )
}
```

**For Integration Tests:**
```groovy
// If testing both behaviors, use both implementations
def 'should work with feature enabled'() {
    given:
    {InterfaceName} featureFlag = new Enabled{InterfaceName}()
    // ... test with enabled
}

def 'should preserve legacy behavior when disabled'() {
    given:
    {InterfaceName} featureFlag = new Noop{InterfaceName}()
    // ... test with disabled
}
```

### 5. Feature Flag Control

**Note:** Feature flags are controlled via cookies in endpoint calls, not environment variables.

**Cookie-Based Control:**
- Feature flags are toggled per request using cookies
- No need to update `env.template` or restart the application
- Allows real-time testing without deployment
- Supports per-user or per-request feature flag state

**Cookie Format:**
- System adds `FF_` prefix automatically to feature flag names
- If you define `@Feature("auction_propagation")`, use cookie: `FF_auction_propagation=true`

**Example Usage:**
```bash
# Enable feature via cookie (note the FF_ prefix)
curl -H "Cookie: FF_auction_propagation=true" \
  https://api.example.com/auctions

# Disable feature via cookie
curl -H "Cookie: FF_auction_propagation=false" \
  https://api.example.com/auctions

# Multiple features
curl -H "Cookie: FF_feature1=true; FF_feature2=false" \
  https://api.example.com/auctions
```

### 6. Validation Checklist

**Before Committing:**
- [ ] All components in single file (interface, Noop, Enabled, Factory)
- [ ] `@Feature` annotation on interface
- [ ] `@Primary` and `@KoverIgnore` on factory
- [ ] `@Component` on all implementations and factory
- [ ] ExpressionBodySyntax for single-statement methods
- [ ] Named arguments for calls with >4 parameters
- [ ] Clear KDoc explaining enabled vs disabled behavior
- [ ] All test fixtures updated with feature flag injection
- [ ] Tests pass: `./gradlew test`
- [ ] Detekt passes: `./gradlew detektMain detektTest`
- [ ] CodeNarc passes: `./gradlew codenarcTest`

### 7. Common Patterns and Examples

**Pattern 1: Simple Delegation (Wrapping Existing Operation)**
```kotlin
@Feature("sequence_assignment")
interface SequenceAssigner {
    fun assign(descriptors: List<Descriptor>): Map<Int, Int>
}

@Component
class NoopSequenceAssigner : SequenceAssigner {
    override fun assign(descriptors: List<Descriptor>): Map<Int, Int> =
        descriptors.associate { it.index to it.currentValue }
}

@Component
class EnabledSequenceAssigner : SequenceAssigner {
    override fun assign(descriptors: List<Descriptor>): Map<Int, Int> =
        ExistingOperation.assignSequences(descriptors)
}
```

**Pattern 2: Complex Implementation (Composite/Multi-step Logic)**
```kotlin
@Feature("batch_validation")
interface BatchValidator {
    fun validate(auction: Auction, batch: Batch): Pair<Batch, List<ValidationError>>
}

@Component
class NoopBatchValidator : BatchValidator {
    override fun validate(
        auction: Auction,
        batch: Batch,
    ): Pair<Batch, List<ValidationError>> = batch to emptyList()
}

@Component
class CompositeBatchValidator : BatchValidator {
    override fun validate(
        auction: Auction,
        batch: Batch,
    ): Pair<Batch, List<ValidationError>> {
        val errors = mutableListOf<ValidationError>()

        // Complex multi-step validation logic
        if (!isValid(batch)) {
            errors.add(ValidationError("Invalid batch"))
        }

        val transformed = transform(batch)
        return transformed to errors
    }

    private fun isValid(batch: Batch): Boolean = /* validation logic */
    private fun transform(batch: Batch): Batch = /* transformation logic */
}
```

**Pattern 3: Return Empty/Default Values (Skip Processing)**
```kotlin
@Feature("enrichment_processing")
interface DataEnricher {
    fun enrich(data: Data): EnrichedData
}

@Component
class NoopDataEnricher : DataEnricher {
    // Skip enrichment - return data unchanged
    override fun enrich(data: Data): EnrichedData =
        EnrichedData(data, metadata = emptyMap())
}

@Component
class FullDataEnricher(
    private val externalService: ExternalService,
    private val cache: CacheService,
) : DataEnricher {
    override fun enrich(data: Data): EnrichedData {
        val metadata = externalService.fetchMetadata(data.id)
        cache.put(data.id, metadata)
        return EnrichedData(data, metadata)
    }
}
```

### 8. Static Analysis Compliance

**Detekt Rules to Watch:**
```kotlin
// ✅ GOOD: ExpressionBodySyntax
override fun simple(): Int = 42

// ❌ BAD: Unnecessary return statement
override fun simple(): Int {
    return 42
}

// ✅ GOOD: Named arguments (>3 params)
UpdateOperation.execute(
    csvRowBatches = batches,
    csvImport = context,
    mergedLotsCache = cache,
    featureFlag = flag,
)

// ❌ BAD: Unnamed arguments (>3 params)
UpdateOperation.execute(batches, context, cache, flag)
```

**CodeNarc Rules for Tests:**
```groovy
// ✅ GOOD: Concrete type
private final MyFeatureFlag featureFlag = new EnabledMyFeatureFlag()

// ❌ BAD: Using 'def'
def featureFlag = new EnabledMyFeatureFlag()

// ✅ GOOD: Line length <120
ImportOperationResult result = UpdateOperation.INSTANCE.execute(
    [[update1, update2]], ctx, [:], sequenceAssigner
)

// ❌ BAD: Line length >120
ImportOperationResult result = UpdateOperation.INSTANCE.execute([[update1, update2]], ctx, [:], sequenceAssigner)
```

### 9. Cleanup Guide (When Feature is Stable)

**Steps to Remove Feature Flag:**
```bash
# 1. Delete feature flag file
rm src/main/kotlin/com/{package}/XxxFeatureFlag.kt

# 2. Remove injection from services
# Replace: private val flag: XxxFeatureFlag
# With: Direct calls to enabled implementation

# 3. Update tests (remove feature flag injection)

# 4. Run verification
./gradlew test detektMain detektTest codenarcTest
```

## Output Format

**Provide:**
1. Complete feature flag file content with all components
2. Service injection updates (show before/after)
3. Test fixture updates (show before/after)
4. Explanation of cookie-based feature flag control (include `FF_` prefix in examples)
5. Command to run: `./gradlew test detektMain detektTest codenarcTest`

**Validation:**
- Explain enabled vs disabled behavior clearly
- Confirm all components in single file
- Verify naming consistency (XxxFeatureFlag pattern)
- Show cookie examples with `FF_` prefix (e.g., `FF_feature_name=true`)
- Check static analysis compliance

## Next Steps

1. Feature flag belongs in Branch 1 — ensure it merges before dependent branches
2. Test flag: set `FF_{feature_name}=true` cookie, verify enabled impl is invoked
3. When feature is stable: follow the cleanup guide at the bottom of this file
4. Run `/atg:verify` after implementing the flag code
