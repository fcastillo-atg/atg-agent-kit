# Recipe: wavebid-a2o feature flag

The single-file Kotlin feature-flag pattern. `/atg:feature-flag` follows this when the resolved
profile's `feature-flag` key names it. Reference implementation:
`src/main/kotlin/com/sellerportal/api/lotimport/LotSequenceAssignmentFeatureFlag.kt`; base
infrastructure in `src/main/kotlin/com/atg/featureflag/FeatureFlags.kt`; rules in
`303-feature-flags.md`.

## Naming

| Part | Convention |
|---|---|
| Flag name | `snake_case` in `@Feature("...")`; cookie is `FF_{name}=true` (prefix added by the system) |
| Interface | `{DomainConcept}` (e.g. `BatchValidator`) |
| Noop impl | `Noop{Interface}` (legacy behaviour, unchanged data or skip) |
| Enabled impl | `Enabled{Interface}` for simple delegation; `Composite`/`Full`/`{Adjective}{Interface}` for real logic |
| Factory | `{Interface}ProxyFactory` |
| File | `{Interface}FeatureFlag.kt` in the feature's package |

## Steps

0. **Check the mechanism exists.** Read `feature-flag` from **atg-repo-profile**. Value `none`:
   print "This service has no feature-flag mechanism. Gate the behaviour another way (config, a
   query parameter, or a separate deploy) or add a mechanism as its own story." and stop. Do not
   invent a flag pattern. Otherwise follow the profile's mechanism — the naming table above and
   the recipe below are the `wavebid-a2o` one.

1. From the requirement, identify the operation to wrap, the interface methods, the enabled
   implementation name, the calling service, and the test fixtures that construct it.
2. Write the single file:

```kotlin
package com.{package}

import com.atg.KoverIgnore
import com.atg.featureflag.Feature
import com.atg.featureflag.FeatureFlagProvider
import com.atg.featureflag.FeatureProxyFactory
import org.springframework.context.annotation.Primary
import org.springframework.stereotype.Component

/**
 * Feature flag wrapper for {description}.
 * Enabled: {new behaviour}. Disabled: {legacy behaviour}.
 * All components live in this file for easy removal.
 */
@Feature("{flag_name}")
interface {Interface} {
    fun {method}({params}): {Return}
}

@Component
class Noop{Interface} : {Interface} {
    override fun {method}({params}): {Return} = {legacyBehaviour}
}

@Component
class {EnabledImpl} : {Interface} {
    override fun {method}({params}): {Return} {
        // new behaviour; in Branch 1 of a multi-branch story throw UnsupportedOperationException
    }
}

@Primary
@Component
@KoverIgnore("FeatureProxyFactory has tests")
class {Interface}ProxyFactory(
    featureFlagProviders: List<FeatureFlagProvider>,
    enabledImplementation: {EnabledImpl},
    disabledImplementation: Noop{Interface},
) : FeatureProxyFactory<{Interface}>(
    {Interface}::class,
    featureFlagProviders,
    enabledImplementation,
    disabledImplementation,
)
```

3. Inject the **interface** (never a concrete class) into the calling service and replace the
   direct call. Spring wires the `@Primary` factory automatically.
4. Update test fixtures: construct `new {EnabledImpl}()` to test the new path and
   `new Noop{Interface}()` to test legacy behaviour; pass it where the service is built. Use
   concrete types, not `def`.
5. Toggle per request with a cookie, no restart or env change:
   `curl -H "Cookie: FF_{flag_name}=true" ...`.
6. Run `./gradlew test detektMain detektTest codenarcTest`.

## Checklist

- [ ] Interface, Noop, Enabled, and factory in one file
- [ ] `@Feature` on the interface; `@Primary` and `@KoverIgnore` on the factory
- [ ] Factory takes `enabledImplementation` before `disabledImplementation`
- [ ] Flag disabled by default; no production behaviour change on merge
- [ ] Fixtures updated; gates green

## Removing the flag later

Delete the `*FeatureFlag.kt` file, call the enabled logic directly where the interface was
injected, drop the fixture injection, run the gates.

**Next:** `/atg:story-impl {TICKET}` to wire the rest of the branch, or `/atg:verify` if the flag was the last change
