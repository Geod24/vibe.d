/**
 * The default convention is to pass parameters via:
 * - query for parameter starting with underscore;
 * - query for GET/PUT requests;
 * - body for POST requests;
 *
 * This is configurable by means of:
 * - headerParam : Get a parameter from the query header;
 * - queryParam : Get a parameter from the query string;
 * - bodyParam : Get a parameter from the body;
 */
module tests.rest.parameters.source.app;

import vibe.core.core;
import vibe.core.log;
import vibe.http.rest;
import vibe.http.router;
import vibe.http.server;

import vibe.http.client : requestHTTP;
import vibe.stream.operations : readAllUTF8;

import core.time;

/* **************************************************************************** *
 *                                   Defaults                                   *
 * **************************************************************************** *
 * Test defaults (= unattributed) parameter passing behave correctly.           *
 * By 'behave correctly', we mean that we are not testing what is going on      *
 * under the hood: we just check that the defaults work together                *
 * (e.g. if the client read GET parameter from the query, then the server has   *
 * to put them in the query.                                                    *
 * **************************************************************************** */

// GET
@rootPathFromName
interface ITestDefaultGet
{
	int getRessource(string param);
}
class TestDefaultGet : ITestDefaultGet
{
override:
	int getRessource(string param) { return 42; }
}

// GET with default parameter
@rootPathFromName
interface ITestDefaultParamGet
{
	string getRessource(string param = "42");
}
class TestDefaultParamGet : ITestDefaultParamGet
{
override:
	string getRessource(string param = "42") { return param; }
}

// POST
@rootPathFromName
interface ITestDefaultPost
{
	void postRessource(string param);
}
class TestDefaultPost : ITestDefaultPost
{
override:
	void postRessource(string param) { assert(param == "42"); }
}

// POST with default parameter
@rootPathFromName
interface ITestDefaultParamPost
{
	struct Aggr { int val; }
	void postRessource(string param = "42");
	void postRessource2(Aggr param = Aggr(43));
}
class TestDefaultParamPost : ITestDefaultParamPost
{
override:
	void postRessource(string param = "42") { assert(param == "42"); }
	// Ensure the default parameter isn't always used.
	void postRessource2(Aggr param = Aggr(43)) { assert(param.val == 42); }
}

// WebParamAttributes tests
@rootPathFromName
interface ITestHeaderParam
{
	@headerParam("param", "Authorization")
	string getResponse(string param);
}
class TestHeaderParam : ITestHeaderParam
{
	override string getResponse(string param) {
		// If the user provided credentials Aladdin / 'open sesame'
		if (param == "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==")
			return "The response is 42";
		return "The cake is a lie";
	}
}

// Test detection of user typos (e.g., if the attribute is on a parameter that doesn't exist).
unittest
{
	@rootPathFromName
	interface ITestHeaderParamTypo
	{
		// Oops !
		@headerParam("ath", "Authorization")
		string getResponse(string auth);
	}
	
	class TestHeaderParamTypo : ITestHeaderParamTypo {
		override string getResponse(string auth) { return "42"; }
	}

	/*
	@rootPathFromName
	interface ITestQueryParamTypo
	{
		// Oops !
		@queryParam("ath", "auth")
		string getResponse(string auth);
	}
	
	class TestQueryParamTypo : ITestQueryParamTypo
	{
		override string getResponse(string auth) { return "42"; }
	}

	@rootPathFromName
	interface ITestBodyParamTypo
	{
		// Oops !
		@headerParam("ath", "auth")
		string getResponse(string auth);
	}
	
	class TestBodyParamTypo : ITestBodyParamTypo
	{
		override string getResponse(string auth) { return "42"; }
	}
	*/

	auto router = new URLRouter;
	// Extra check in case the interface would not compile anymore...
	static assert(__traits(compiles, new TestHeaderParamTypo()));
	// We detect it server side...
	// @@ Test disabled due to compiler unknown bug (linker failure) @@
	//static assert(!__traits(compiles, registerRestInterface(router, new TestHeaderParamTypo())));
	// And client side...
	static assert(!__traits(compiles, new RestInterfaceClient!ITestHeaderParamTypo("http://127.0.0.1:8080")));

	//static assert(__traits(compiles, new TestQueryParamTypo()));
	//static assert(!__traits(compiles, registerRestInterface(router, new TestQueryParamTypo())));
	//static assert(!__traits(compiles, new RestInterfaceClient!ITestQueryParamTypo("http://127.0.0.1:8080")));
	
	//static assert(__traits(compiles, new TestBodyParamTypo()));
	//static assert(!__traits(compiles, registerRestInterface(router, new TestBodyParamTypo())));
	//static assert(!__traits(compiles, new RestInterfaceClient!ITestBodyParamTypo("http://127.0.0.1:8080")));
}


// Test for user mistakes (Multiple attributes for the same interface).
unittest
{
	@rootPathFromName
	interface ITestHeaderParamMisconfig
	{
		// Replace the second headerParam by @queryParam / bodyParam once it's implemented.
		@headerParam("auth", "Authorization") @headerParam("auth", "Content-Type")
		string getResponse(string auth, string other);
	}
	
	class TestHeaderParamMisconfig : ITestHeaderParamMisconfig
	{
		override string getResponse(string auth, string other) { return "42"; }
	}

	/*
	@rootPathFromName
	interface ITestQueryParamMisconfig
	{
		// Replace the second headerParam by @queryParam / bodyParam once it's implemented.
		@queryParam("ath", "auth")
		string getResponse(string auth, string other);
	}
	
	class TestQueryParamMisconfig : ITestQueryParamMisconfig
	{
	  override string getResponse(string auth, string other) { return "42"; }
	}

	@rootPathFromName
	interface ITestBodyParamMisconfig
	{
		// Replace the second headerParam by @queryParam / bodyParam once it's implemented.
		@headerParam("auth", "auth")
		string getResponse(string auth, string other);
	}
	
	class TestBodyParamMisconfig : ITestBodyParamMisconfig
	{
	  override string getResponse(string auth, string other) { return "42"; }
	}
	*/

	auto router = new URLRouter;
	static assert(__traits(compiles, new TestHeaderParamMisconfig()));
	// BUG: Linker failure
	//static assert(!__traits(compiles, registerRestInterface(router, new TestHeaderParamMisconfig())));

	//static assert(__traits(compiles, new TestQueryParamMisconfig()));
	//static assert(!__traits(compiles, registerRestInterface(router, new TestQueryParamMisconfig())));

	//static assert(__traits(compiles, new TestBodyParamMisconfig()));
	//static assert(!__traits(compiles, registerRestInterface(router, new TestBodyParamMisconfig())));
}


shared static this()
{
	setLogLevel(LogLevel.debug_);
	// Registering our REST services in router
	auto routes = new URLRouter;
	// Defaults
	registerRestInterface(routes, new TestDefaultGet());
	registerRestInterface(routes, new TestDefaultParamGet());
	registerRestInterface(routes, new TestDefaultPost());
	registerRestInterface(routes, new TestDefaultParamPost());
	// WebParamAttributes
	registerRestInterface(routes, new TestHeaderParam());

	auto settings = new HTTPServerSettings();
	// Use an unused port for parallel testing.
	settings.port = 15422;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	enum LstURL = "http://127.0.0.1:15422/";

	listenHTTP(settings, routes);

	// Let a warmup time.
	setTimer(1.seconds, {
			scope(exit) exitEventLoop(true);

			// TODO: White box testing for default parameters
			logInfo("Testing defaults (unattributed) GET/POST");
			{
				// GET
				auto api0 = new RestInterfaceClient!ITestDefaultGet(LstURL);
				auto answer0 = api0.getRessource("Hello there");
				assert(answer0 == 42);
				auto api1 = new RestInterfaceClient!ITestDefaultParamGet(LstURL);
				auto answer1 = api1.getRessource();
				assert(answer1 == "42");
				// POST
				auto api2 = new RestInterfaceClient!ITestDefaultPost(LstURL);
				api2.postRessource("42");
				auto api3 = new RestInterfaceClient!ITestDefaultParamPost(LstURL);
				api3.postRessource();
				api3.postRessource2(ITestDefaultParamPost.Aggr(42));

			}

			logInfo("Testing headerParam");
			{
				auto api = new RestInterfaceClient!ITestHeaderParam(LstURL);
				// First we make sure parameters are transmitted via headers.
				auto res = requestHTTP(LstURL~"i_test_header_param/response",
						       (scope r) {
							       r.method = HTTPMethod.GET;
							       r.headers["Authorization"] = "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==";
						       });

				assert(res.statusCode == 200);
				assert(res.bodyReader.readAllUTF8() == `"The response is 42"`);
				// Then we check that both can communicate together.
				auto answer = api.getResponse("Hello there");
				assert(answer == "The cake is a lie");
			}

			//logInfo("Testing queryParam");
			//logInfo("Testing bodyParam");

			logInfo("Success.");
		});
}
