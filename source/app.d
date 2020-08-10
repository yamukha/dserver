import vibe.d;     //https://vibed.org/docs
import std.stdio;
import std.json;
import deimos.sodium;
import core.stdc.stdlib;
import core.thread;
import std.digest.sha;
import std.string;
import tinyredis;  //https://adilbaig.github.io/Tiny-Redis/

__gshared Redis conn = void;
__gshared ulong block  = 0;
__gshared bool started = false;
__gshared bool running = true;

class WebService
{
    private SessionVar!(string, "username")
      username_;

    void index(HTTPServerResponse res) {
        auto contents = q{<html> <head> <title>http fake mining server</title> </head> <body> </body> </html>};
        res.writeBody(contents,"text/html; charset=UTF-8");
    }

    // curl  127.0.0.1:2826/blocks
    @path("/blocks")
    void getBlocks(HTTPServerRequest req, HTTPServerResponse res) {
        auto contents = q{};
        res.writeBody(contents, "text/html; charset=UTF-8");
        writeln("GET at /blocks ", block );
        // GET all blocks
        auto keys_resp = conn.send("KEYS *");
        string keys_str = keys_resp.toString;
        string keys = strip(keys_str, "[", "]");
        auto a = split(keys, ',');
        writeln("[");
        for (int n = 0; n < a.length; ++n) {
          auto k = strip (a[n], " ", "'");
          string rq = format!"%s %s"("GET ", k);
          auto blk = conn.send(rq);
          auto s = blk.toString;
          writeln(s);
          if (n < a.length-1 ) writeln(",");
        }
        writeln("]");
    }

    //curl -X POST -H "Content-Type: application/json" http://127.0.0.1:2826/transaction --data-raw '{"outputs":[{"key":"0xee0edfbe581fa81481e858f75fda3414cd3a655ff17ec987af775e666412bf1f","amount":4000000},{"key":"0xf4012c71c9be512613c4820a3f6b1e55f8515a441913cf9cb06ccc3076ccbebd","amount":96000000}],"inputs":[{"hash":"0xc2c5be0cb790c8d85b9096c409dd439aebaa9af6df2e476d23f8d6f624e87f95","sig":"0x0ec47ca9f8d0101a8c3cabf6ba1fa73aa123294dcf0f5578addc5f01463f7dfc1bd3719636a77f3e4f95b07f1b77a2a58df046c6aa66e4bec91d908a66c3f608","index":0},{"hash":"0xc2c5be0cb790c8d85b9096c409dd439aebaa9af6df2e476d23f8d6f624e87f95","sig":"0x096a7ff44ee2a1d88674b2ba5583a00fd47ccb80ebc2761b40361e4319bc7da9080304ea87d46c5401d6b92f4304fb176f1f5e0dce9872024297659be7a83774","index":1}]}'
    @path("/transaction")
    void postTransaction(HTTPServerRequest req, HTTPServerResponse res) {
        auto contents = q{};

        res.writeBody(contents,"text/html; charset=UTF-8");	
        auto s = req.bodyReader.readAllUTF8();
        //writeln("POST at /transaction ", s);

        JSONValue j = parseJSON(s);
        auto o = j["outputs"].get!(JSONValue[]);

        for (int n = 0; n < o.length; ++n) {
          auto key = o[n]["key"].str;
          auto amo = o[n]["amount"].get!int;
        
          writeln("key = " , key ); 
          writeln("amount = " , amo ); 
        }

        auto i = j["inputs"].get!(JSONValue[]);
        for (int n = 0; n < i.length; ++n) {
          auto hsh = i[n]["hash"].str;
          auto ind = i[n]["index"].get!int;
        
          writeln("hash = " , hsh ); 
          writeln("index = " , ind ); 
        }

        if  (!started) {
          started = true;
          auto composed = new Thread(&threadMining).start();
          writeln("started = " , started ); 
        }
    }
}

void threadMining()
{
  string prev =  to!string("0x0000000000000000000000000000000000000000000000000000000000000000");

  while (running)
  {
    if (started) {
      Thread.sleep( dur!("msecs")( 1000 ) );
      //writeln("more one block ", block);

      ubyte[crypto_box_SECRETKEYBYTES] key;
      ubyte[crypto_box_PUBLICKEYBYTES] pkey;
      ubyte[crypto_box_MACBYTES]    mac;

      randombytes_buf(key.ptr, key.length);
      randombytes_buf(mac.ptr, mac.length);

      string trans = "{}";
      string jblock =  format!"\'{\n \"previous\" : %s,\n \"nonce\" : 0x%s,\n \"height\" : %d,\n \"transaction\" : %s \n}\'"(prev, toHexString(mac), block, trans);
      //[ { "previous": "0x0000000000000000000000000000000000000000000000000000000000000000", "nonce": 524632, "height": 0 } ]
      writeln(jblock);
      string dat = format!"%s %s%d %s"("SET", "block",block, jblock);
      conn.send(dat);

      ubyte [] MESSAGE;
      MESSAGE.length = jblock.length;
      MESSAGE = cast( ubyte[]) jblock;

      ubyte[32] hash256 = sha256Of(MESSAGE);
      string curr = format!"%s%s"("0x",toHexString(hash256));
      prev = curr;
      block++;
    /*
      //encrypt i.e. transaction
      ubyte [] ciphertext;
      ciphertext. length = MESSAGE.length + crypto_box_MACBYTES;
      crypto_box_easy (ciphertext.ptr, MESSAGE.ptr, MESSAGE.length, mac.ptr, key.ptr, key.ptr);
      //writeln("ciphertext :" , ciphertext);

      // decrypt i.e transaction
      ubyte [] msg;
      msg.length = jblock.length;
      //crypto_box_open_easy(decrypted, ciphertext, nonce, alice_publickey, bob_secretkey));
      crypto_box_open_easy (msg.ptr, ciphertext.ptr, ciphertext.length, mac.ptr, key.ptr, key.ptr);

      string omsg = cast(string)msg;
      //writeln("message :" ,  omsg);
	*/  
    }
    else {
      Thread.sleep(dur!("msecs")(1000));
    }
  }
}

extern(C) void signal(int sig, void function(int));
extern(C) void exit(int exit_val);
extern(C) void handle(int sig) {
    writeln("Control-C was pressed..aborting program....goodbye...");
    exit(EXIT_SUCCESS);
}

void main() {
    if (sodium_init() < 0) {
      writeln("sodium init error");
      exit(EXIT_FAILURE);
    }
    enum SIGINT = 2;
    signal(SIGINT,&handle);
   
    conn = new Redis("localhost", 6379);
    conn.send("FLUSHALL");  

    auto router = new URLRouter;
    router.registerWebInterface(new WebService);

    auto settings = new HTTPServerSettings;
    settings.sessionStore =  new MemorySessionStore;
    settings.port = 2826;
    listenHTTP(settings, router);

    runApplication();

    scope (exit){ 
      writeln("Cleanup"); 
      running = false;
    }
}
