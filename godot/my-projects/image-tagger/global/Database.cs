using Godot;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using LiteDB;
using ImageMagick;
using Alphaleonis.Win32.Filesystem;

public class KomiHashInfo {
	public ulong komihash { get; set; }
	public bool filter { get; set; }
	public HashSet<string> paths { get; set; }
	public HashSet<string> tags { get; set; }
}

public class Database : Node {
	// need to do a speed comparsion between
	// 		col.FindById(sha256);
	// and 
	//		col.FindOne(Query.EQ("sha256", sha256))
	// if they are about the same or 2nd one is faster I will leave the Ids as numbers and add a sha256 variable
	// if the first one is significantly faster then I will instead add an index variable to the class and use sha256 as the id
	
	public bool use_journal = true;
	
	public string metadata_path;
	public void SetMetadataPath(string path) { metadata_path = path; }
	
	
	public LiteDatabase db_komihash;
	public ILiteCollection<KomiHashInfo> col_komihash;
	public Dictionary<ulong, KomiHashInfo> komihash_info = new Dictionary<ulong, KomiHashInfo>();
	
	public int Create() {
		try {
			if (use_journal) {
				db_komihash = new LiteDatabase(metadata_path + "komihash_info.db");
				BsonMapper.Global.Entity<KomiHashInfo>().Id(x => x.komihash);		// not needed if FindOne() is faster or the same
				col_komihash = db_komihash.GetCollection<KomiHashInfo>("komihashes");
			}
			return 0;
		}
		catch (Exception ex) { GD.Print("Database::Create(): ", ex); return 1; }
	}
	public void Destroy() {
		db_komihash.Dispose();
	}
	
	public void LoadAllKomiHash() {
		try {
			var komihashes = col_komihash.FindAll();
			if (komihashes != null) 
				foreach (KomiHashInfo khash in komihashes) 
					komihash_info[khash.komihash] = khash;
		} 
		catch (Exception ex) { GD.Print("LoadAllSHA256() : ", ex); }
	}
	
	/* LoadRangeSHA256()
	 * DESC: loads a number of SHA256s from the Database into sha256_info starting at 'start'
	 * NOTE: assumes that I will use numeric IDs, just change _Id checks to index otherwise
	 * TODO: add options related to filtering and sorting (needs to be done on the database if I am only retrieving a section of the shas)
	*/
	public void LoadRangeKomiHash(int start, int number) {
		try {
			var komihashes = col_komihash.Find(Query.Between("_Id", start, start+number));
			if (komihashes != null) 
				foreach (KomiHashInfo khash in komihashes)
					komihash_info[khash.komihash] = khash;
		}
		catch (Exception ex) { GD.Print("LoadRangeSHA256() : ", ex); } 
	}
	
	/* needs try/catch */
	public void InsertKomiHashInfo(ulong komihash1, bool filter1, string[] paths1, string[] tags1) {
		var komihash_info = new KomiHashInfo {
			komihash = komihash1,
			filter = filter1,
			paths = new HashSet<string>(paths1),
			tags = new HashSet<string>(tags1)
		};
		col_komihash.Insert(komihash_info);
	}
	
	
	public bool GetFilterSHA(ulong hash) { return (komihash_info.ContainsKey(hash)) ? komihash_info[hash].filter : false; }
	public string[] GetPathsSHA(ulong hash) { return (komihash_info.ContainsKey(hash)) ? (komihash_info[hash].paths != null) ? komihash_info[hash].paths.ToArray() : new string[0] : new string[0]; } /* returns empty string array if paths is null or key is not found, otherwise returns the paths array */
	public string[] GetTagsSHA(ulong hash) { return (komihash_info.ContainsKey(hash)) ? (komihash_info[hash].tags != null) ? komihash_info[hash].tags.ToArray() : new string[0] : new string[0]; }
	/* not 100% sure the above 2 lines work yet, but it does not have any compile errors (never used encapsulated ternary operators before) */
	
}
