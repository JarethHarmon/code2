using Godot;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using LiteDB;
using ImageMagick;
using Alphaleonis.Win32.Filesystem;

public class SHA256Info {
	//public int index { get; set; } 			// not needed if FindOne() is faster or the same
	public string sha256 { get; set; }
	public bool filter { get; set; }		// probably change into a Dictionary of settings (actually flags would be better)
	public HashSet<string> paths { get; set; }
	public HashSet<string> tags { get; set; }
}

public class Database : Node
{
	// need to do a speed comparsion between
	// 		col.FindById(sha256);
	// and 
	//		col.FindOne(Query.EQ("sha256", sha256))
	// if they are about the same or 2nd one is faster I will leave the Ids as numbers and add a sha256 variable
	// if the first one is significantly faster then I will instead add an index variable to the class and use sha256 as the id
	
	public string metadata_path;
	public bool use_journal = true;
	
	public LiteDatabase db_sha256;
	
	public ILiteCollection<SHA256Info> sha256s;
	
	public Dictionary<string, SHA256Info> sha256_info = new Dictionary<string, SHA256Info>();
	
	public void SetMetadataPath(string path) { metadata_path = path; }
	
	public void Create() {
		if (use_journal) {
			db_sha256 = new LiteDatabase(metadata_path + "sha256_info.db");
			BsonMapper.Global.Entity<SHA256Info>().Id(x => x.sha256);		// not needed if FindOne() is faster or the same
			sha256s = db_sha256.GetCollection<SHA256Info>("sha256s");
		}
	}
	
	public void Destroy() {
		db_sha256.Dispose();
	}
	
	public void LoadAllSHA256() {
		try {
			var shas = sha256s.FindAll();
			if (shas != null) foreach (SHA256Info sha in shas) 
				sha256_info[sha.sha256] = sha;
		} 
		catch (Exception ex) { GD.Print("LoadAllSHA256() : ", ex); }
	}
	
	/* LoadRangeSHA256()
	 * DESC: loads a number of SHA256s from the Database into sha256_info starting at 'start'
	 * NOTE: assumes that I will use numeric IDs, just change _Id checks to index otherwise
	 * TODO: add options related to filtering and sorting (needs to be done on the database if I am only retrieving a section of the shas)
	*/
	public void LoadRangeSHA256(int start, int number) {
		try {
			var shas = sha256s.Find(Query.Between("_Id", start, start+number));
			if (shas != null) foreach (SHA256Info sha in shas)
				sha256_info[sha.sha256] = sha;
		}
		catch (Exception ex) { GD.Print("LoadRangeSHA256() : ", ex); } 
	}
	
	/* needs try/catch */
	public void InsertSHAInfo(string sha2561, bool filter1, string[] paths1, string[] tags1) {
		var sha_info = new SHA256Info {
			sha256 = sha2561,
			filter = filter1,
			paths = new HashSet<string>(paths1),
			tags = new HashSet<string>(tags1)
		};
		sha256s.Insert(sha_info);
	}
	
	
	public bool GetFilterSHA(string sha256) { return (sha256_info.ContainsKey(sha256)) ? sha256_info[sha256].filter : false; }
	public string[] GetPathsSHA(string sha256) { return (sha256_info.ContainsKey(sha256)) ? (sha256_info[sha256].paths != null) ? sha256_info[sha256].paths.ToArray() : new string[0] : new string[0]; } /* returns empty string array if paths is null or key is not found, otherwise returns the paths array */
	public string[] GetTagsSHA(string sha256) { return (sha256_info.ContainsKey(sha256)) ? (sha256_info[sha256].tags != null) ? sha256_info[sha256].tags.ToArray() : new string[0] : new string[0]; }
	/* not 100% sure the above 2 lines work yet, but it does not have any compile errors (never used encapsulated ternary operators before) */
	
}
