package.path = "./?.lua;./?/init.lua;" .. package.path

local Diagnostics = require("runcompass.diagnostics")

local function assertEqual(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end
end

local function assertContains(value, expected, message)
  if not string.find(value, expected, 1, true) then error(message or ("expected '" .. expected .. "' in '" .. value .. "'")) end
end

local function testCatalogSummaryIncludesCoverageAndRuleVersions()
  local summary = Diagnostics.catalog(
    { total = 9, classified = 8, unmapped = 1, invalid = {} },
    { version = "1.5.0", source = "vanilla:test", modeled = 12, total = 12, curated = 3, baseline = 9, dataUpdateRequired = 0 },
    { total = 4 }
  )
  assertEqual(summary.modelVersion, "1.5.0", "catalog diagnostics should retain the live model version")
  assertEqual(summary.baseline, 9, "catalog diagnostics should retain baseline coverage")
  assertEqual(summary.interactionRules, 4, "catalog diagnostics should retain interaction-rule coverage")
  assertContains(Diagnostics.formatCatalog(summary), "modelVersion=1.5.0", "catalog output should expose model version")
end

local function testStatusSummaryIncludesCapabilitiesAndModelSource()
  local summary = Diagnostics.status(
    { tier = "enhanced", repentogonVersion = "1.1.0", diagnostics = { completionMarks = "read API unavailable" } },
    { version = "1.5.0", source = "vanilla:test" },
    "boss.delirium"
  )
  assertEqual(summary.target, "boss.delirium", "status diagnostics should retain the selected target")
  assertContains(Diagnostics.formatStatus(summary), "tier=enhanced", "status output should expose capability tier")
  assertContains(Diagnostics.formatStatus(summary), "modelSource=vanilla:test", "status output should expose model source")
  assertContains(Diagnostics.formatStatus(summary), "completionMarks", "status output should expose degraded capability probes")
end

local tests = { testCatalogSummaryIncludesCoverageAndRuleVersions, testStatusSummaryIncludesCapabilitiesAndModelSource }
for index, test in ipairs(tests) do test(); print("diagnostics ok " .. index) end
print(#tests .. " diagnostics tests passed")
