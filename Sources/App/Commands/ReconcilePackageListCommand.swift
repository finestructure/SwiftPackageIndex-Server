import Fluent
import FluentPostgreSQL
import Vapor

final class ReconcilePackageListCommand: Command {
  static let name = "reconcile_package_list"

  var arguments: [CommandArgument] = []
  var options: [CommandOption] = []
  var help = ["Synchronise the database with the master package list from GitHub."]

  func run(using context: CommandContext) throws -> Future<Void> {
    // Grab the GitHub master package list and the database's current package list
    let masterPackageList = try fetchMasterPackageList(context)
    let currentPackageList = try fetchCurrentPackageList(context)

    // Reconcile the package lists and add/remove any new/deleted packages
    return masterPackageList.and(currentPackageList).flatMap { (master, current) in
      let reconciler = PackageListReconciler(masterPackageList: master, currentPackageList: current)

      return context.container.withPooledConnection(to: .psql) { database in
        // Add any new packages
        let packageAdditions = reconciler.packagesToAdd.map { url -> Future<Package> in
          let package = Package(url: url)
          return package.create(on: database).map { package -> Package in
            print("Added \(package.url)")
            return package
          }
        }.flatten(on: database)

        // Delete any removed packages
        let packageDeletions = reconciler.packagesToDelete.map { url in
          return Package.findByUrl(on: database, url: url).flatMap { package -> Future<Void> in
            return package.delete(on: database).map {
              print("Deleted \(package.url)")
            }
          }
        }.flatten(on: database)

        // Queue up all of the additions and deletions for execution
        return packageAdditions.and(packageDeletions)
          .transform(to: ())
      }
    }
  }

  func fetchMasterPackageList(_ context: CommandContext) throws -> Future<[URL]> {
    return try context.container.client()
      .get(masterPackageListURL)
      .flatMap(to: [String].self) { response in
        // GitHub serves the file as text/plain so it needs to be forced as JSON
        response.http.contentType = .json
        return try response.content.decode([String].self)
      }.flatMap { urlStrings in
      var urls = [URL]()
      var errorNotifications = [Future<Void>]()

      for urlString in urlStrings {
        // If this isn't a valid URL, post an error
        guard let url = URL(string: urlString) else {
          try errorNotifications.append(self.sendInvalidURLString(urlString, on: context))
          continue
        }

        // Otherwise, we're all good
        urls.append(url)
      }

      return errorNotifications
        .flatten(on: context.container)
        .transform(to: urls)
      }
  }

  func fetchCurrentPackageList(_ context: CommandContext) throws -> Future<[URL]> {
    return context.container.withPooledConnection(to: .psql) { database in
      return Package.query(on: database).all()
    }.map { packages in
      // Grab just the package URLs
      packages.compactMap { $0.url }
    }
  }

  func sendInvalidURLString(_ invalidURL: String, on context: CommandContext) throws -> Future<Void> {
    // Send a notification of the invalid package to Rollbar
    if let rollbarAPIToken = Environment.get("ROLLBAR_API_KEY") {
      return try context.container.make(Client.self).post("https://api.rollbar.com/api/1/item/") { rollbarRequest in
        let data = try RollbarCreateItem(accessToken: rollbarAPIToken, environment: Environment.detect().name, level: .warning, body: "URL \(invalidURL) is not a valid URL")
        try rollbarRequest.content.encode(data)
      }.transform(to: ())
    } else {
      return context.container.future()
    }
  }

  var masterPackageListURL: URL {
    guard let url = URL(string: "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json")
      else { preconditionFailure("Failed to create the master package list URL") }
    return url
  }
}
