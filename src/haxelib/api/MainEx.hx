package haxelib.api;

import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.zip.Reader;
import haxe.zip.Writer;
import sys.FileSystem;
import sys.io.File;
import haxelib.client.FsUtils.*;

using StringTools;

class MainEx extends haxelib.client.Main {
    public function new() {
        super();
		settings = {
			debug: false,
			quiet: false,
			always: true,
			never: false,
			flat: false,
			global: false,
			system: false,
		};
    }
    
	function infoEx(prj) {
		//var prj = param("Library name");
        var inf = null;
        try {
            inf = site.infos(prj);
        } catch (e:Dynamic) {
            throw e;
        }
        /*
		print("Name: "+inf.name);
		print("Tags: "+inf.tags.join(", "));
		print("Desc: "+inf.desc);
		print("Website: "+inf.website);
		print("License: "+inf.license);
		print("Owner: "+inf.owner);
		print("Version: "+inf.getLatest());
		print("Releases: ");
		if( inf.versions.length == 0 )
			print("  (no version released yet)");
		for( v in inf.versions )
			print("   "+v.date+" "+v.name+" : "+v.comments);
            */
        return inf;
	}
    
	function listEx(filter:String = null) {
		var rep = getRepository();
		var folders = FileSystem.readDirectory(rep);
		//var filter = paramOpt();
		if ( filter != null )
			folders = folders.filter( function (f) return f.toLowerCase().indexOf(filter.toLowerCase()) > -1 );
		var all = [];
		for( p in folders ) {
			if( p.charAt(0) == "." )
				continue;

			var current = try getCurrent(rep + p) catch(e:Dynamic) continue;
			var dev = try getDev(rep + p) catch( e : Dynamic ) null;

			var semvers = [];
			var others = [];
			for( v in FileSystem.readDirectory(rep+p) ) {
				if( v.charAt(0) == "." )
					continue;
				v = Data.unsafe(v);
				var semver = try SemVer.ofString(v) catch (_:Dynamic) null;
				if (semver != null)
					semvers.push(semver);
				else
					others.push(v);
			}

			if (semvers.length > 0)
				semvers.sort(SemVer.compare);

			var versions = [];
			for (v in semvers)
				versions.push((v : String));
			for (v in others)
				versions.push(v);

			if (dev == null) {
				for (i in 0...versions.length) {
					var v = versions[i];
                    /*
					if (v == current)
						versions[i] = '[$v]';
                        */
				}
			} else {
				//versions.push("[dev:"+dev+"]");
                current = "dev:" + dev + "";
                versions.push("dev:"+dev+"");
			}

            var info = new HaxeLibInfo();
            info.name = Data.unsafe(p);
            info.availableLocalVersions = versions;
            info.currentLocalVersion = current;
            info.localRootPath = Path.normalize(rep + "/" + info.name);
            all.push(info);
            
			//all.push(Data.unsafe(p) + ": "+versions.join(" "));
		}
		all.sort(function(s1, s2) return Reflect.compare(s1.name.toLowerCase(), s2.name.toLowerCase()));
        /*
		for (p in all) {
			print(p);
		}
        */
        
        return all;
	}
    
	function doInstallEx( rep, project, version, setcurrent, cb:Dynamic->Void) {
		// check if exists already
		if( FileSystem.exists(rep+Data.safe(project)+"/"+Data.safe(version)) ) {
			//print("You already have "+project+" version "+version+" installed");
			setCurrent(rep, project, version, false);
            cb({
                message: "You already have "+project+" version "+version+" installed",
                type: "complete"
            });
			return true;
		}

		// download to temporary file
		var filename = Data.fileName(project,version);
		var filepath = rep+filename;
		var out = try File.append(filepath,true) catch (e:Dynamic) throw 'Failed to write to $filepath: $e';
		out.seek(0, SeekEnd);

		var h = createHttpRequest(siteUrl+Data.REPOSITORY+"/"+filename);

		var currentSize = out.tell();
		if (currentSize > 0)
			h.addHeader("range", "bytes="+currentSize + "-");

		var progress = new ProgressOutEx(out, currentSize, "download", cb);

		var has416Status = false;
		h.onStatus = function(status) {
			// 416 Requested Range Not Satisfiable, which means that we probably have a fully downloaded file already
			if (status == 416) has416Status = true;
		};
		h.onError = function(e) {
			progress.close();

			// if we reached onError, because of 416 status code, it's probably okay and we should try unzipping the file
			if (!has416Status) {
				FileSystem.deleteFile(filepath);
				throw e;
			}
		};
//		print("Downloading "+filename+"...");
        cb({
            type: "download",
            message: "Downloading "+filename+"..."
        });
		h.customRequest(false,progress);

        var r = true;
        trace("DO INSTALL EX");
		doInstallFileEx(rep,filepath, setcurrent, cb);
		try {
			site.postInstall(project, version);
		} catch (e:Dynamic) {}
        
        cb({
            type: "complete"
        });
        
        return r;
	}
    
    function doInstallFileEx(rep,filepath,setcurrent,nodelete = false, cb:Dynamic->Void) {
		// read zip content
		var f = File.read(filepath,true);
		var zip = try {
			Reader.readZip(f);
		} catch (e:Dynamic) {
			f.close();
			// file is corrupted, remove it
			if (!nodelete)
				FileSystem.deleteFile(filepath);
			//neko.Lib.rethrow(e);
			throw e;
		}
		f.close();
		var infos = Data.readInfos(zip,false);
		//print('Installing ${infos.name}...');
        cb({
            type: "install",
            message: 'Installing ${infos.name}...'
        });
        
		// create directories
		var pdir = rep + Data.safe(infos.name);
		safeDir(pdir);
		pdir += "/";
		var target = pdir + Data.safe(infos.version);
		safeDir(target);
		target += "/";

		// locate haxelib.json base path
		var basepath = Data.locateBasePath(zip);

		// unzip content
		var entries = [for (entry in zip) if (entry.fileName.startsWith(basepath)) entry];
		var total = entries.length;
		for (i in 0...total) {
			var zipfile = entries[i];
			var n = zipfile.fileName;
			// remove basepath
			n = n.substr(basepath.length,n.length-basepath.length);
			if( n.charAt(0) == "/" || n.charAt(0) == "\\" || n.split("..").length > 1 )
				throw "Invalid filename : "+n;

			if (!settings.debug) {
                /*
				var percent = Std.int((i / total) * 100);
				Sys.print('${i + 1}/$total ($percent%)\r');
                */
				var percent = Std.int((i / total) * 100);
                cb({
                    type: "install",
                    cur: i + 1,
                    max: total,
                    message: 'Unzipping: ${i + 1}/$total ($percent%)'
                });
			}

			var dirs = ~/[\/\\]/g.split(n);
			var path = "";
			var file = dirs.pop();
			for( d in dirs ) {
				path += d;
				safeDir(target+path);
				path += "/";
			}
			if( file == "" ) {
				if( path != "" && settings.debug ) print("  Created "+path);
				continue; // was just a directory
			}
			path += file;
			if (settings.debug)
				print("  Install "+path);
			var data = Reader.unzip(zipfile);
			File.saveBytes(target+path,data);
		}

		// set current version
		if( setcurrent || !FileSystem.exists(pdir+".current") ) {
			File.saveContent(pdir + ".current", infos.version);
			//print("  Current version is now "+infos.version);
            cb({
                type: "install",
                message: "Current version is now "+infos.version
            });
		}

		// end
		if( !nodelete )
			FileSystem.deleteFile(filepath);
		//print("Done");

		// process dependencies
		doInstallDependencies(rep, infos.dependencies);

		return infos;
    }
    
	function devEx(project:String, dir:String) {
		var rep = getRepository();
		//var project = param("Library");
		//var dir = paramOpt();
		var proj = rep + Data.safe(project);
		if( !FileSystem.exists(proj) ) {
			FileSystem.createDirectory(proj);
		}
		var devfile = proj+"/.dev";
		if( dir == null ) {
			if( FileSystem.exists(devfile) )
				FileSystem.deleteFile(devfile);
			//print("Development directory disabled");
		}
		else {
			while ( dir.endsWith("/") || dir.endsWith("\\") ) {
				dir = dir.substr(0,-1);
			}
			if (!FileSystem.exists(dir)) {
				//print('Directory $dir does not exist');
			} else {
				dir = FileSystem.fullPath(dir);
				try {
					File.saveContent(devfile, dir);
					//print("Development directory set to "+dir);
				}
				catch (e:Dynamic) {
					//print('Could not write to $devfile');
				}
			}

		}
	}
    
	function submitEx(file:String, user:String, password:String, cb:Dynamic->Void) {
		//var file = param("Package");

		var data, zip;
		if (FileSystem.isDirectory(file)) {
			zip = zipDirectory(file);
			var out = new BytesOutput();
			new Writer(out).write(zip);
			data = out.getBytes();
		} else {
			data = File.getBytes(file);
			zip = Reader.readZip(new haxe.io.BytesInput(data));
		}

		var infos = Data.readInfos(zip,true);
		Data.checkClassPath(zip, infos);

		//var user:String = infos.contributors[0];

        /*
		if (infos.contributors.length > 1)
			do {
				print("Which of these users are you: " + infos.contributors);
				user = param("User");
			} while ( infos.contributors.indexOf(user) == -1 );
        */
            
		/*
        var password;
		if( site.isNewUser(user) ) {
			print("This is your first submission as '"+user+"'");
			print("Please enter the following informations for registration");
			password = doRegister(user);
		} else {
			password = readPassword(user);
		}
        */
        
		site.checkDeveloper(infos.name,user);

		// check dependencies validity
		for( d in infos.dependencies ) {
			var infos = site.infos(d.name);
			if( d.version == "" )
				continue;
			var found = false;
			for( v in infos.versions )
				if( v.name == d.version ) {
					found = true;
					break;
				}
			if( !found )
				throw "Library " + d.name + " does not have version " + d.version;
		}

		// check if this version already exists

		var sinfos = try site.infos(infos.name) catch ( _ : Dynamic ) null;
        // TODO: should probably check this also at some point
        /*
		if( sinfos != null )
			for( v in sinfos.versions )
				if( v.name == infos.version && !ask("You're about to overwrite existing version '"+v.name+"', please confirm") )
					throw "Aborted";
        */
                    
		// query a submit id that will identify the file
		var id = site.getSubmitId();

		// directly send the file data over Http
		var h = createHttpRequest("http://"+haxelib.client.Main.SERVER.host+":"+haxelib.client.Main.SERVER.port+"/"+haxelib.client.Main.SERVER.url);
		h.onError = function(e) throw e;
		h.onData = print;
		h.fileTransfer("file",id,new ProgressInEx(new haxe.io.BytesInput(data),data.length, cb),data.length);
		print("Sending data.... ");
		h.request(true);

		// processing might take some time, make sure we wait
		print("Processing file.... ");
		if (haxe.remoting.HttpConnection.TIMEOUT != 0) // don't ignore -notimeout
			haxe.remoting.HttpConnection.TIMEOUT = 1000;
		// ask the server to register the sent file
		var msg = site.processSubmit(id,user,password);
		print(msg);
	}
}