unittest
{
	foreach (x; ["o8p93ghkcnahuecsoa", "D言語くん可愛い!", "if (auto p = key in aarr) return *p;", "assert (['a'] == \"a\""])
		assert (x.encodeTw() == x.encodeTwTrans());
}

import
	std.array,  // replace
	std.string, // translate
	std.uri;

string encodeTw(string str){
    string ret = encodeComponent(str);
    ret = replace(ret, "!", "&21");
    ret = replace(ret, "*", "&2A");
    ret = replace(ret, "'", "&27");
    ret = replace(ret, "(", "&28");
    ret = replace(ret, ")", "&29");
    return ret;
}

string encodeTwTrans(string str)
{
	return str.encodeComponent().translate([
		'!': "&21",
		'*': "&2A",
		'\'': "&27",
		'(': "&28",
		')': "&29",
	]);
}
