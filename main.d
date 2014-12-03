import gtk.MainWindow;
import gtk.Label;
import gtk.Main;
import gtk.Entry;
import gtk.Box;
import gtk.Button;
import gtk.Widget;

import gdk.Event;

import std.digest.sha,
       std.algorithm,
       std.datetime,
       std.net.curl,
       std.base64,
       std.array,
       std.regex,
       std.stdio,
       std.json,
       std.conv,
       std.typecons,
       std.string,
       std.uri;

alias Tuple!(string, "key", string, "value") Token;

// thread-safe singleton
mixin template Singleton(){
    public static typeof(this) get(){
        __gshared typeof(this)  _instance;
        static bool _trFlag = false;
        if(!_trFlag){
            synchronized{
                if(_instance is null){
                    _instance = new typeof(this);
                }
            }
            _trFlag = true;
        }
        return _instance;
    }   
}

string encodeTw(string str){
    string ret = encodeComponent(str);
    ret = replace(ret, "!", "&21");
    ret = replace(ret, "*", "&2A");
    ret = replace(ret, "'", "&27");
    ret = replace(ret, "(", "&28");
    ret = replace(ret, ")", "&29");
    return ret;
}


class Twitter{
public:
    mixin Singleton;
    static this(){
        // とりあえずKeyは直書き
        auto fin = File("consumer.txt");  
        consumerKey       = chomp(fin.readln());
        consumerKeySecret =  chomp(fin.readln());
        accessToken = chomp(fin.readln());
        accessTokenSecret = chomp(fin.readln());
    }
    auto sendTweet(string text){
        string[string] params = ["status" : text,
                                 "include_entities" : "true"];
        return signedPost("https://api.twitter.com/1.1/statuses/update.json", params);
    }

    auto getHomeTimeline(int count = 20){
        auto url = "https://api.twitter.com/1.1/statuses/home_timeline.json";
        string[string] params = ["count" : to!string(count)];
        auto ret = signedGet(url, params);

        int x;
        string buf;
        bool push;
        string[] dat;
        dat.length = count;
        int pt;
        foreach (rp; ret){
            if(rp == '{'){
                if(x == 0){
                    buf = "";
                    push = true;
                }
                buf ~= rp;
                x++;
            }else if(rp == '}'){
                x--;
                buf ~= rp;
                if(x == 0){
                    push = false;
                    dat[pt++] = buf;
                }
            }else if(push){
                buf ~= rp;
            }
        }
       
        foreach(el; dat){ 
            auto parsed = parseJSON(el);
            writeln("\r------------------------------------------------------------------------------");
            writefln("%s:\n%s", parsed.object["user"].object["name"].str, parsed.object["text"].str);
            writeln("------------------------------------------------------------------------------");
        }
    }

    auto beginUserStream(){
        auto url = "https://userstream.twitter.com/1.1/user.json";
        auto path = getHttpOptions("GET", url); 
        signedGet(url);
        ////////////// under construction /////////////
        return;
    }
private:
    ubyte[] hmac_sha1(in string key, in string message){
        auto padding(in ubyte[] k){
            auto h = (64 < k.length)? sha1Of(k): k;
            return h ~ new ubyte[64 - h.length];
        }
        const k = padding(cast(ubyte[])key);
        return sha1Of((k.map!q{cast(ubyte)(a^0x5c)}.array) ~ sha1Of((k.map!q{cast(ubyte)(a^0x36)}.array) ~ cast(ubyte[])message)).dup;
    }

    // Calculating OAuthSignature
    string createSignature(in string cks, in string ats, in string method, in string url, string[string] params){
        // URIEncode
        foreach(k, v; params)  params[k] = encodeTw(v);
    
        auto query = params.keys.sort.map!(k => k ~ "=" ~ params[k]).join("&");
        auto key = [cks, ats].map!encodeTw.join("&");
        auto base = [method, url, query].map!encodeTw.join("&");
        string oauthSignature = encodeTw(Base64.encode(hmac_sha1(key, base)));

        return oauthSignature;
    }

    auto getHttpOptions(in string method, in string uri, in string[string] params = null){
        string now = Clock.currTime.toUnixTime.to!string;
        string[string] para = [
                       "oauth_consumer_key"     : consumerKey,
                       "oauth_nonce"            : now,
                       "oauth_signature_method" : "HMAC-SHA1",
                       "oauth_timestamp"        : now,
                       "oauth_token"            : accessToken,
                       "oauth_version"          : "1.0"];
        foreach(k, v; params) para[k] = v;
        
        string oauthSignature = createSignature(consumerKeySecret, accessTokenSecret, method, uri, para);
        para["oauth_signature"] = oauthSignature;

        auto authorize_keys = para.keys.filter!q{a.countUntil("oauth_")==0};
        auto authorize = "OAuth " ~ authorize_keys.map!(x => x ~ "=" ~ para[x]).join(",");

        auto option_keys = para.keys.filter!q{a.countUntil("oauth_")!=0};
        auto option = option_keys.map!(x => x ~ "=" ~ para[x]).join("&");

        return  tuple(authorize, option);
    }

    string signedCall(in string method, in string uri, in string[string] params, string delegate(HTTP, in string, in string) call){
        auto op = getHttpOptions(method, uri, params);

        auto http = HTTP();
        http.caInfo("cacert.pem");
        http.addRequestHeader("Authorization", op[0]);
        return call(http, uri, op[1]);
    }

    string signedGet(in string uri, string[string] param = null) {
        return signedCall("GET", uri, param, (http, uri, option){return cast(immutable).get((0 < option.length)? uri ~ "?" ~ option: uri, http);});
    }
    string signedPost(in string uri, string[string] param = null){
        return signedCall("POST", uri, param, (http, uri, option){return cast(immutable)post(uri, option, http);});
    }

    static const string consumerKey;
    static const string consumerKeySecret;
    static const string accessToken;
    static const string accessTokenSecret;
}

class TweetButton : Button{
    this(Entry ent){
        super("Tweet!");
        modifyFont("Arial", 14);
        addOnButtonRelease(&tweet);
        entry = ent;
    }

    private bool tweet(Event event, Widget widget){
        Twitter tw = Twitter.get();
        tw.sendTweet(entry.getText());
        return true;
    }

    private Entry entry;
}

void main(string[] args){
    Main.init(args);
    MainWindow win = new MainWindow("Dwarf");
    win.setDefaultSize(400, 300);

    Twitter.get().getHomeTimeline();

    Box box = new Box(Orientation.VERTICAL, 10);
    box.add(new Label("Hello World"));
    Entry ent = new Entry();
    box.add(ent);
    box.add(new TweetButton(ent));
    win.add(box);
    win.showAll();
    Main.run();
}



