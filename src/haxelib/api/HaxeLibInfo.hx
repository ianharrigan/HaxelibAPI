package haxelib.api;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class HaxeLibInfo {
    public var name:String = null;
    public var currentLocalVersion:String = null;
    public var availableLocalVersions:Array<String> = [];
    public var localRootPath:String = null;
    
    public var owner:String;
    public var website:String;
    public var downloads:Int = -1;
    public var description:String;
    public var license:String;
    public var tags:Array<String> = [];
    public var contributors:Array<HaxeLibUserInfo> = [];
    public var releases:Array<HaxeLibReleaseInfo> = [];
    
    public var userData:Dynamic;
    
    public function new() {
    }
    
    public var isDev(get, null):Bool;
    private function get_isDev():Bool {
        return StringTools.startsWith(currentLocalVersion, "dev:");
    }

    public var isGit(get, null):Bool;
    private function get_isGit():Bool {
        return StringTools.startsWith(currentLocalVersion, "git");
    }
    
    public var currentLocalPath(get, null):String;
    private function get_currentLocalPath():String {
        if (isDev == true) {
            return currentLocalVersion.substring("dev:".length);
        }
        return Path.normalize(localRootPath + "/" + HaxeLibApi.safeName(currentLocalVersion));
    }
    
    public function mergeInfo(with:HaxeLibInfo) {
        if (with.name != null) {
            this.name = with.name;
        }
        if (with.owner != null) {
            this.owner = with.owner;
        }
        if (with.website != null) {
            this.website = with.website;
        }
        if (with.downloads > -1) {
            this.downloads = with.downloads;
        }
        if (with.description != null) {
            this.description = with.description;
        }
        if (with.license != null) {
            this.license = with.license;
        }
        if (with.tags != null && with.tags.length > 0) {
            this.tags = with.tags.copy();
        }
        if (with.releases != null && with.releases.length > 0) {
            this.releases = with.releases.copy();
        }
        if (with.contributors != null && with.contributors.length > 0) {
            this.contributors = with.contributors.copy();
        }
        
    }
    
    public function refreshLocalInfo() {
        var api = new HaxeLibApi();
        var info = api.listLocal(name)[0];
        if (info == null) {
            throw "Could not find haxelib '" + name + "'";
        }
        localRootPath = info.localRootPath;
        currentLocalPath = info.currentLocalPath;
        currentLocalVersion = info.currentLocalVersion;
        availableLocalVersions = info.availableLocalVersions;
    }
    
    public function enrich() {
        var haxelibJsonFile = Path.normalize(currentLocalPath + "/haxelib.json");
        if (FileSystem.exists(haxelibJsonFile) == false) {
            return;
        }
        
        try {
            var haxelibJson = Json.parse(File.getContent(haxelibJsonFile));
            
            if (haxelibJson.description != null) {
                description = haxelibJson.description;
            }
            if (haxelibJson.license != null) {
                license = haxelibJson.license;
            }
            if (haxelibJson.url != null) {
                website = haxelibJson.url;
            }
            if (haxelibJson.tags != null) {
                tags = haxelibJson.tags;
            }
            if (haxelibJson.contributors != null) {
                var array:Array<String> = haxelibJson.contributors;
                contributors = [];
                for (a in array) {
                    var user = new HaxeLibUserInfo();
                    user.username = a;
                    contributors.push(user);
                }
            }
        } catch (e:Dynamic) {
            trace("Problem loading haxelib file (" + haxelibJsonFile + "): " + e);
        }
    }
}