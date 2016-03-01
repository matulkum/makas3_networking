/**
 * Created by mak on 27/01/16.
 */
package de.creativetechnologist.socket {
import flash.utils.ByteArray;

public interface ITypedTCPSocket {
	function get remotePort(): int;

	function dispose(): void;

	function get connected(): Boolean;

	function close(): void;

	function sendInt(value: int, type: uint = 0): void;

	function sendString(string: String, type: uint = 0): void;

	function sendObject(data: Object, type: uint = 0): void;

	/**
	 * Sends a message without data
	 * @param type
	 */
	function sendType(type: uint): void;

	function addListenerForType(type: uint, listener: Function): void;

	function removeListenerForType(type: uint, listener: Function): void;

}
}
