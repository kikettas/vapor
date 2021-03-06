import COperatingSystem
import Vapor
import Dispatch
import Foundation

do {
    var services = Services.default()

    var middlewareConfig = MiddlewareConfig()
    middlewareConfig.use(ErrorMiddleware.self)
    middlewareConfig.use(DateMiddleware.self)
    middlewareConfig.use(SessionsMiddleware.self)
    services.register(middlewareConfig)


    let dir = DirectoryConfig(workDir: "/Users/tanner/dev/vapor/vapor/Sources/Development/")
    services.register(dir)

    let router = EngineRouter.default()

    router.get("search") { req -> String in
        return try req.query.get(String.self, at: ["query"])
    }

    router.get("hash", String.parameter) { req -> String in
        let string = try req.parameter(String.self)
        return try req.make(BCryptHasher.self).make(string)
    }

    router.get("set") { req -> String in
        let session = try req.session()
        session["foo"] = "bar"
        return "done"
    }

    router.get("get") { req -> String  in
        let session = try req.session()
        return session["foo"] ?? "none"
    }

    router.get("del") { req -> String  in
        try req.destroySession()
        return "deleted"
    }

    router.get("ping") { req in
        return "123" as StaticString
    }

    router.get("client", "zombo") { req -> Future<Response> in
        let client = try req.make(Client.self)
        return client.send(.GET, to: "http://www.zombo.com/")
    }

    router.get("client", "romans") { req -> Future<Response> in
        let client = try req.make(Client.self)
        return client.send(.GET, to: "http://www.romansgohome.com")
    }

    router.get("client", "example") { req -> Future<Response> in
        let client = try req.make(Client.self)
        return client.send(.GET, to: "http://example.com")
    }

    router.get("client", "httpsbin") { req -> Future<String> in
        return try req.make(Client.self).get("https://httpbin.org/anything").flatMap(to: Data.self) { res in
            return res.http.body.consumeData(max: 2048, on: req)
        }.map(to: String.self) { data in
            return String(data: data, encoding: .utf8) ?? "n/a"
        }
    }

    router.get("client", "invalid") { request -> Future<String> in
        return try request.make(Client.self).get("http://httpbin.org")
            .flatMap(to: Data.self) { response in
                return response.http.body.consumeData(max: 2048, on: request)
            }
            .map(to: String.self) { data in
                return String(data: data, encoding: .utf8) ?? ""
        }
    }

    router.get("client", "httpbin") { req -> Future<String> in
        return try req.make(Client.self).get("http://httpbin.org/anything").flatMap(to: Data.self) { res in
            return res.http.body.consumeData(max: 2048, on: req)
        }.map(to: String.self) { data in
            return String(data: data, encoding: .utf8) ?? "n/a"
        }
    }

    struct LoginRequest: Content {
        var email: String
        var password: String
    }

    router.post(LoginRequest.self, at: "login") { req, loginRequest -> Response in
        print(loginRequest.email) // user@vapor.codes
        print(loginRequest.password) // don't look!

        return req.makeResponse()
    }

    router.get("string", String.parameter) { req -> String in
        return try req.parameter(String.self)
    }

    router.get("error") { req -> Future<String> in
        throw Abort(.internalServerError, reason: "Test error")
    }

    router.get("fast") { req -> Response in
        let res = req.makeResponse()
        res.http.body = HTTPBody(string: "123")
        return res
    }

    router.get("123") { req in
        return "123"
    }

    router.get("vapor") { req -> Future<String> in
        return try req.make(Client.self).send(.GET, to: "https://vapor.codes").map(to: String.self) { res in
            print(res.http.headers)
            return "done!"
        }
    }

    router.get("query") { req -> String in
        struct Hello: Decodable {
            var name: String?
            var flag: Bool?
        }
        let hello = try req.query.decode(Hello.self)
        print(hello.flag ?? false)
        return hello.name ?? "none"
    }

    router.get("redirect") { req in
        return req.redirect(to: "http://google.com")
    }

    router.get("template") { req -> Future<View> in
        return try req.view().render("hello")
    }

    router.grouped(DateMiddleware.self).get("datetest") { req in
        return HTTPStatus.ok
    }

    services.register(Router.self) { _ in return router }

    let app = try Application(environment: .detect(), services: services)
    try app.run()
} catch {
    print("Top Level Error: \(error)")
    exit(1)
}
