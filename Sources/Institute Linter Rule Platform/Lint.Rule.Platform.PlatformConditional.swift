// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// Wave 3 (mechanization-program) — platform identity checks MUST use
/// `#if os(...)`, not `#if canImport(...)`.
///
/// Citation: `[PATTERN-004a]` (platform skill — source-level platform
/// conditionals).
extension Lint.Rule {
  public static let `canimport conditional` = Lint.Rule(
    id: "canimport conditional",
    default: .warning,
    findings: { source, severity in
      let visitor = PlatformPlatformConditionalVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

@usableFromInline
internal let platformPlatformConditionalMessage: Swift.String =
  "[canimport conditional] [PATTERN-004a]: platform "
  + "identity check uses `#if canImport(...)` on a platform-prefixed "
  + "module — `canImport` evaluates against module resolution (varies "
  + "by build system); platform identity is what `#if os(...)` is "
  + "for (evaluates against the target triple). Reserve `canImport` "
  + "for module availability: optional feature modules (`SwiftUI`, "
  + "`Combine`, etc.) and the raw C-library trellis "
  + "(`#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)`), "
  + "which is genuine module availability — `os(Linux)` cannot "
  + "distinguish Glibc from Musl. Institute platform-prefixed modules "
  + "(`Darwin_Kernel_Standard` etc.) are the forbidden shape."

/// Raw C-library / system-SDK modules whose `canImport` IS module
/// availability, not platform identity — exempt (#16 Option C ledger,
/// Entry II.2 DECISION 2026-07-23). The canonical libc trellis
/// `#if canImport(Darwin) || canImport(Glibc) || canImport(Musl)` cannot
/// be expressed with `os()` without losing the Musl arm (`os(Linux)` is
/// true for both Glibc and Musl), so the skill's own determinism table
/// (`platform/compilation.md` [PATTERN-004a]) does not condemn it. Each
/// entry is an importable C-interop module shipped by a toolchain/SDK:
///
///   - `Darwin` — Apple libSystem clang module
///   - `Glibc` / `Musl` / `Bionic` — Linux/Android libc modules
///   - `Android` — Android NDK module
///   - `WASILibc` — WASI libc module
///   - `WinSDK` / `ucrt` / `CRT` — Windows SDK / C runtime modules
///
/// Bare `Linux` / `Windows` are NOT importable modules — `canImport` on
/// them is always false and remains flagged (platform-identity confusion
/// plus a latent dead branch).
internal let platformPlatformConditionalCLibraryModules: Swift.Set<Swift.String> = [
  "Darwin",
  "Glibc",
  "Musl",
  "Bionic",
  "Android",
  "WASILibc",
  "WinSDK",
  "ucrt",
  "CRT",
]

internal let platformPlatformConditionalPlatformPrefixes: Swift.Set<Swift.String> = [
  "Darwin",
  "Linux",
  "Windows",
  "Glibc",
  "Musl",
  "Bionic",
  "WinSDK",
]

internal func platformPlatformConditionalIsPlatformModuleName(_ name: Swift.String) -> Swift.Bool {
  // Exempt the raw C-library / system-SDK modules (#16 Entry II.2):
  // gating on their importability is the sanctioned libc trellis.
  if platformPlatformConditionalCLibraryModules.contains(name) { return false }
  if platformPlatformConditionalPlatformPrefixes.contains(name) { return true }
  for prefix in platformPlatformConditionalPlatformPrefixes {
    if name.hasPrefix("\(prefix)_") { return true }
  }
  return false
}

internal final class PlatformPlatformConditionalVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  var matches: [Diagnostic.Record] = []

  init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
    guard let condition = node.condition else { return .visitChildren }
    checkCondition(condition)
    return .visitChildren
  }

  private func checkCondition(_ expression: ExprSyntax) {
    if let call = expression.as(FunctionCallExprSyntax.self) {
      if let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
        callee.baseName.text == "canImport"
      {
        if let argument = call.arguments.first,
          let identifier = argument.expression.as(DeclReferenceExprSyntax.self)
        {
          if platformPlatformConditionalIsPlatformModuleName(
            identifier.baseName.text
          ) {
            let position = identifier.baseName.positionAfterSkippingLeadingTrivia
            let location = converter.location(for: position)
            matches.append(
              Diagnostic.Record(
                location: Source.Location(
                  fileID: source.fileID,
                  filePath: source.filePath,
                  line: location.line,
                  column: location.column
                ),
                severity: severity,
                identifier: "canimport conditional",
                message: platformPlatformConditionalMessage
              ))
          }
        }
      }
    }
    if let sequence = expression.as(SequenceExprSyntax.self) {
      for element in sequence.elements {
        checkCondition(element)
      }
    }
    if let infix = expression.as(InfixOperatorExprSyntax.self) {
      checkCondition(infix.leftOperand)
      checkCondition(infix.rightOperand)
    }
    if let prefix = expression.as(PrefixOperatorExprSyntax.self) {
      checkCondition(prefix.expression)
    }
  }
}
