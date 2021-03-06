// swiftlint:disable force_unwrapping

import XCTest

@testable import App

final class PackageListReconcilerTests: XCTestCase {
  func testReconcileNoChanges() {
    let master = [
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/second")!,
      URL(string: "https://example.com/third")!,
      URL(string: "https://example.com/fourth")!]
    let current = [
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/second")!,
      URL(string: "https://example.com/third")!,
      URL(string: "https://example.com/fourth")!]

    let reconciler = PackageListReconciler(masterPackageList: master, currentPackageList: current)

    XCTAssertEqualPackageLists(reconciler.packagesToDelete, [])
    XCTAssertEqualPackageLists(reconciler.packagesToAdd, [])
  }

  func testReconcileAddingPackages() {
    let master = [
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/second")!,
      URL(string: "https://example.com/third")!,
      URL(string: "https://example.com/fourth")!]
    let current = [URL(string: "https://example.com/first")!]

    let reconciler = PackageListReconciler(masterPackageList: master, currentPackageList: current)

    XCTAssertEqualPackageLists(reconciler.packagesToAdd, [
      URL(string: "https://example.com/second")!,
      URL(string: "https://example.com/third")!,
      URL(string: "https://example.com/fourth")!])
    XCTAssertEqualPackageLists(reconciler.packagesToDelete, [])
  }

  func testReconcilingPackagesWithDuplicates() {
    let master = [
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/second")!]
    let current: [URL] = []

    let reconciler = PackageListReconciler(masterPackageList: master, currentPackageList: current)

    XCTAssertEqualPackageLists(reconciler.packagesToAdd, [
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/second")!])
    XCTAssertEqualPackageLists(reconciler.packagesToDelete, [])
  }

  func testReconcileDeletingPackages() {
    let master = [URL(string: "https://example.com/first")!]
    let current = [
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/second")!,
      URL(string: "https://example.com/third")!,
      URL(string: "https://example.com/fourth")!]

    let reconciler = PackageListReconciler(masterPackageList: master, currentPackageList: current)

    XCTAssertEqualPackageLists(reconciler.packagesToAdd, [])
    XCTAssertEqualPackageLists(reconciler.packagesToDelete, [
      URL(string: "https://example.com/second")!,
      URL(string: "https://example.com/third")!,
      URL(string: "https://example.com/fourth")!])
  }

  func testReconcileAddingAndDeletingPackages() {
    let master = [
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/second")!,
      URL(string: "https://example.com/fifth")!,
      URL(string: "https://example.com/sixth")!]
    let current = [
      URL(string: "https://example.com/first")!,
      URL(string: "https://example.com/second")!,
      URL(string: "https://example.com/third")!,
      URL(string: "https://example.com/fourth")!]

    let reconciler = PackageListReconciler(masterPackageList: master, currentPackageList: current)

    XCTAssertEqualPackageLists(reconciler.packagesToAdd, [
      URL(string: "https://example.com/fifth")!,
      URL(string: "https://example.com/sixth")!])
    XCTAssertEqualPackageLists(reconciler.packagesToDelete, [
      URL(string: "https://example.com/third")!,
      URL(string: "https://example.com/fourth")!])
  }
}

/// As package lists come from sets, their elements can be in any order. Compare them as sorted arrays.
/// - Parameters:
///   - first: The first array.
///   - second: The second array.
func XCTAssertEqualPackageLists(_ first: [URL], _ second: [URL], file: StaticString = #file, line: UInt = #line) {
  // Sorted arrays should be exactly equal
  let firstSorted = first.map { $0.absoluteString }.sorted()
  let secondSorted = second.map { $0.absoluteString }.sorted()
  XCTAssertEqual(firstSorted, secondSorted, file: file, line: line)
}
