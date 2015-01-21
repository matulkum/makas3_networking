/**
 * Created by mak on 21.08.14.
 */
package de.creativetechnolgist.socket {
public class NamedData {

	public var name: String;
	public var content: *;

	public function NamedData(name: String = null, content:* = null) {
		set(name, content);
	}


	public function set(name: String, content:*): void {
		this.name = name;
		this.content = content;
	}


	public function toString(): String {
		var string: String = 'name: ';
		if( content )
			string += content.toString();

		return string;
	}
}
}
