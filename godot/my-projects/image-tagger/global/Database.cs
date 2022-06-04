using Godot;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using LiteDB;
using ImageMagick;
using Alphaleonis.Win32.Filesystem;

public class Komi64Info {
	public string komi64 { get; set; }
	public bool filter { get; set; }
	public HashSet<string> paths { get; set; }
	public HashSet<string> tags { get; set; }
}

public class Database : Node {
	public bool use_journal = true;	
	public string metadata_path;
	public void SetMetadataPath(string path) { metadata_path = path; }
	
	public LiteDatabase db_komi64;
	public ILiteCollection<Komi64Info> col_komi64;
	public Dictionary<string, Komi64Info> dict_komi64 = new Dictionary<string, Komi64Info>();
	
	public int Create() {
		try {
			if (use_journal) {
				db_komi64 = new LiteDatabase(metadata_path + "komi64_info.db");
				BsonMapper.Global.Entity<Komi64Info>().Id(x => x.komi64);		
				col_komi64 = db_komi64.GetCollection<Komi64Info>("komihashes");
			}
			return 0;
		}
		catch (Exception ex) { GD.Print("Database::Create() : ", ex); return 1; }
	}
	public void Destroy() { db_komi64.Dispose(); }
	public void CheckpointKomi64() { db_komi64.Checkpoint(); }
	
	public void LoadAllKomi64() {
		try {
			var komihashes = col_komi64.FindAll();
			if (komihashes != null) 
				foreach (Komi64Info khinfo in komihashes) 
					dict_komi64[khinfo.komi64] = khinfo;
		} 
		catch (Exception ex) { GD.Print("Database::LoadAllKomi64() : ", ex); }
	}
	
	/* DESC: loads a number of Komihashes from the Database into komihash_info starting at 'start'+1
	 * TODO: add options related to filtering and sorting (needs to be done on the database if I am only retrieving a section of the shas)*/
	public void LoadRangeKomi64(int start, int number) {
		try {
			var komihashes = col_komi64.Find(Query.All(), start, limit:number);
			if (komihashes != null) 
				foreach (Komi64Info khinfo in komihashes)
					dict_komi64[khinfo.komi64] = khinfo;
		}
		catch (Exception ex) { GD.Print("Database::LoadRangeKomi64() : ", ex); } 
	}	
	
	public int InsertKomi64Info(string komi64_n, bool filter_n, string[] paths_n, string[] tags_n) {
		try {
			if (col_komi64.FindOne(Query.EQ("_Id", komi64_n)) != null) return 1; // duplicate
			var komi64_info = new Komi64Info {
				komi64 = komi64_n,
				filter = filter_n,
				paths = new HashSet<string>(paths_n),
				tags = new HashSet<string>(tags_n)
			};
			col_komi64.Insert(komi64_info);
			return 0;
		}
		//catch (SomeSpecificException sse) {}
		catch (Exception ex) { GD.Print("Database::InsertKomi64Info() : ", ex); return -1; }
	}
	
	public string[] GetAllKomi64FromDict() { return dict_komi64.Keys.ToArray(); }
	public bool GetKomiFilterFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? dict_komi64[komi64].filter : false; }
	public string[] GetKomiPathsFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? (dict_komi64[komi64].paths != null) ? dict_komi64[komi64].paths.ToArray() : new string[0] : new string[0]; }
	public string[] GetKomiTagsFromDict(string komi64) { return (dict_komi64.ContainsKey(komi64)) ? (dict_komi64[komi64].tags != null) ? dict_komi64[komi64].tags.ToArray() : new string[0] : new string[0]; }
		
}
