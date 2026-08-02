local Diagnostics = {}

function Diagnostics.catalog(catalogReport, modelReport, rulesReport)
  catalogReport, modelReport, rulesReport = catalogReport or {}, modelReport or {}, rulesReport or {}
  return {
    rulesVersion = catalogReport.version or "unknown",
    total = catalogReport.total or 0,
    classified = catalogReport.classified or 0,
    unmapped = catalogReport.unmapped or 0,
    invalid = #(catalogReport.invalid or {}),
    modelVersion = modelReport.version or "unknown",
    modelSource = modelReport.source or "unknown",
    modeled = modelReport.modeled or 0,
    modelTotal = modelReport.total or 0,
    curated = modelReport.curated or 0,
    baseline = modelReport.baseline or 0,
    dataUpdateRequired = modelReport.dataUpdateRequired or 0,
    interactionRules = rulesReport.total or 0
  }
end

function Diagnostics.status(capabilities, modelReport, target)
  capabilities, modelReport = capabilities or {}, modelReport or {}
  return {
    tier = capabilities.tier or "base",
    repentogonVersion = capabilities.repentogonVersion,
    target = target,
    modelVersion = modelReport.version or "unknown",
    modelSource = modelReport.source or "unknown",
    unavailableCapabilities = capabilities.diagnostics or {}
  }
end

function Diagnostics.formatCatalog(report)
  return table.concat({
    "catalog=" .. tostring(report.rulesVersion),
    "total=" .. tostring(report.total),
    "classified=" .. tostring(report.classified),
    "unmapped=" .. tostring(report.unmapped),
    "invalid=" .. tostring(report.invalid),
    "modelVersion=" .. tostring(report.modelVersion),
    "models=" .. tostring(report.modeled) .. "/" .. tostring(report.modelTotal),
    "curated=" .. tostring(report.curated),
    "baseline=" .. tostring(report.baseline),
    "dataUpdateRequired=" .. tostring(report.dataUpdateRequired),
    "interactionRules=" .. tostring(report.interactionRules)
  }, ", ")
end

function Diagnostics.formatStatus(report)
  local unavailable = {}
  for key, value in pairs(report.unavailableCapabilities or {}) do unavailable[#unavailable + 1] = tostring(key) .. "=" .. tostring(value) end
  table.sort(unavailable)
  local result = {
    "tier=" .. tostring(report.tier),
    "target=" .. tostring(report.target),
    "modelVersion=" .. tostring(report.modelVersion),
    "modelSource=" .. tostring(report.modelSource)
  }
  if report.repentogonVersion then result[#result + 1] = "repentogon=" .. tostring(report.repentogonVersion) end
  if #unavailable > 0 then result[#result + 1] = "capabilities=" .. table.concat(unavailable, ";") end
  return table.concat(result, ", ")
end

return Diagnostics
