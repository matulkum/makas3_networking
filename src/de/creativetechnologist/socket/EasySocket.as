/**
 * Created by mak on 21.08.14.
 */
package de.creativetechnolgist.socket {
import de.creativetechnolgist.log.Log;

import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.net.Socket;
import flash.utils.ByteArray;
import flash.utils.Dictionary;
import flash.utils.Timer;

import org.osflash.signals.Signal;

public class EasySocket {

	public var reconnectTimerDelay: Number = 4000;

	private var socket: Socket;

	private var _remotePort: int;
	public function get remotePort(): int {return _remotePort;}

	private var _remoteHost: String;
	public function get remoteHost(): String{ return _remoteHost ;}

	private var keepAlive: Boolean;

	private var sendData: NamedData;
	private var type2globalListenerSignals = Dictionary;

	private var notConnectedBuffer: Vector.<NamedData> = new <NamedData>[];

	private var retryTimer: Timer;

	private var isInit: Boolean;

	private var receivingMessageLength: uint = 0;
	private var receivingMessageType: uint = 0;

	//TODO create getter
	public var onConnectedSignal: Signal;
	public var onClosedSignal: Signal;
	public var onIOErrorSignal: Signal;
	public var onReceivingObjectWithTypeSignal: Signal;
	public var onObjectReceived: Signal;

	public static const TYPE_BYTES : uint = 1;
	public static const TYPE_STRING : uint = 2;
	public static const TYPE_INT : uint = 3;
	public static const TYPE_OBJECT : uint = 1000;
//	public static const TYPE_NAMED_DATA : uint = 4;


	public function EasySocket(socket: Socket = null) {
		this.socket = socket;
		onConnectedSignal = new Signal(EasySocket);
		onClosedSignal = new Signal(EasySocket);
		onIOErrorSignal = new Signal(EasySocket, IOErrorEvent);
		onObjectReceived = new Signal(EasySocket, uint, Object);

		// target, type, ratio
		onReceivingObjectWithTypeSignal = new Signal(EasySocket, uint, Number);

		type2globalListenerSignals = new Dictionary();
		if( socket )
			addSocketListener();
	}


	public function dispose(): void {
		if( socket ) {
			removeSocketListeners();
			socket.close();
			socket = null;
		}
		if( retryTimer ) {
			retryTimer.stop();
			retryTimer.removeEventListener(TimerEvent.TIMER, onRetryTimer);
		}
	}


	public function get connected(): Boolean {
		if( !socket ) return false;
		return socket.connected;
	}


	public function connect(remoteHost: String, remotePort: int, keepAlive: Boolean = true): Boolean {
		Log.debug('SignalSenderSocket -> init()', remoteHost, remotePort);

		this.keepAlive = keepAlive;
		if( keepAlive ) {
			if( !retryTimer ) {
				retryTimer = new Timer(reconnectTimerDelay, 1);
				retryTimer.addEventListener(TimerEvent.TIMER, onRetryTimer);
			}
			else {
				retryTimer.reset();
			}
		}
		retryTimer.start();

		if(socket) {
			if( socket.connected )
				socket.close();
			removeSocketListeners();
			socket = null;
		}

		this._remoteHost = remoteHost;
		this._remotePort = remotePort;

		try {
			socket = new Socket();
			addSocketListener();
			socket.connect(remoteHost, remotePort);
		}
		catch (e: Error) {
			trace(e.toString());
			return false;
		}

		isInit = true;
		return true;
	}


//	public function sendNamedData(name: String, content: *, putInQueueIfNotConnected: Boolean = false): void {
//		if( !sendData )
//			sendData = new NamedData(name, content);
//		else
//			sendData.set(name, content);
//		if( !socket || !socket.connected) {
//			if( putInQueueIfNotConnected) {
//				notConnectedBuffer.push(sendData);
//				trace('not coneected yet');
//			}
//		}
//		else {
//			sendObject(sendData, TYPE_NAMED_DATA);
////			sendSignalSocketData(sendData);
//		}
//	}


	public function sendObjectWithType(type: uint, data: Object, putInQueueIfNotConnected: Boolean = false): void {
		if( !socket || !socket.connected) {
			if( putInQueueIfNotConnected) {
				var namedData: NamedData = new NamedData(type.toString(), data);
				notConnectedBuffer.push(namedData);
				trace('not coneected yet');
			}
		}
		else {
			var bytes: ByteArray = new ByteArray();
			bytes.writeObject(data);
			bytes.position = 0;
			sendBytesWithType(type, bytes);
		}

	}


	public function sendBytesWithType(type: uint, data: ByteArray): void {
		var sendData: ByteArray = new ByteArray();
		sendData.writeUnsignedInt(data.length);
		sendData.writeUnsignedInt(type);
		data.position = 0;
		sendData.writeBytes(data);

		sendData.position = 0;
		socket.writeBytes(sendData);
		socket.flush();
	}



	public function addListener(type: uint, handler: Function): void {
		var signal: Signal = type2globalListenerSignals[type] as Signal;
		if( !signal ) {
			signal = new Signal();
			type2globalListenerSignals[type] = signal;
		}
		signal.add(handler);
	}


	public function removeListener(type: String, handler: Function): void {
		var signal: Signal = type2globalListenerSignals[type] as Signal;
		if( signal ) {
			signal.remove(handler);
		}
	}


	private function addSocketListener(): void {
		socket.addEventListener(Event.CONNECT, onSocketConnect);
		socket.addEventListener(Event.CLOSE, onSocketClose);
		socket.addEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
		socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);
	}


	private function removeSocketListeners(): void {
		socket.removeEventListener(Event.CONNECT, onSocketConnect);
		socket.removeEventListener(Event.CLOSE, onSocketClose);
		socket.removeEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
		socket.removeEventListener(IOErrorEvent.IO_ERROR, onSocketError);
	}


	private function onRetryTimer(event: TimerEvent): void {
		Log.debug('EasySocket -> onRetryTimer()');
		connect( _remoteHost, _remotePort, keepAlive);
	}


	private function onClientSocketData(event: ProgressEvent): void {

		var clientSocket: Socket = event.target as Socket;

		if(clientSocket.bytesAvailable < 8 ) {
			Log.debug('package to small');
		}
		// 4 bytes for message length + 4 bytes for messageType
		while ( clientSocket.bytesAvailable >= 8 ) {
			// is it a new Message?
			if( receivingMessageLength == 0) {
				receivingMessageLength = clientSocket.readUnsignedInt();
				receivingMessageType = clientSocket.readUnsignedInt();

//				Log.debug('receiving new message with type '+ receivingMessageType + ' and length ' + receivingMessageLength);
			}
			// is there a full message in this packet?
			if( receivingMessageLength <= clientSocket.bytesAvailable) {
//				Log.debug('received new message with type '+ receivingMessageType);

				var bytes: ByteArray = new ByteArray();
				var data: *;
				clientSocket.readBytes(bytes, 0, receivingMessageLength);
				bytes.position = 0;


				if( receivingMessageType == TYPE_STRING) {
					data = bytes.readUTF();
				}
				else if( receivingMessageType == TYPE_INT ) {
					data = bytes.readInt();
				}
				// is receiving type serializable?
				else if( receivingMessageType >= TYPE_OBJECT ) {
					data = bytes.readObject();
				}
				else {
					data = bytes;
				}

				// dispatch for instances which listen just for a specific name
				var signal: Signal = type2globalListenerSignals[receivingMessageType] as Signal;
				if( signal ) {
					signal.dispatch(this, receivingMessageType, data);
				}

				// dispatch for all
				onObjectReceived.dispatch(this, receivingMessageType, data);

				receivingMessageLength = 0;
				receivingMessageType = 0;
			}
			// is message loading in progress?
			else {
				Log.debug('EasySocket -> onClientSocketData(): waiting for next package');
				if(receivingMessageLength > 0)
					onReceivingObjectWithTypeSignal.dispatch(this, receivingMessageType, clientSocket.bytesAvailable / receivingMessageLength);

				break;
			}

		}

	}


	private function onSocketConnect(event: Event): void {
		Log.info('EasySocket -> onSocketConnect()');
		if( retryTimer ) {
			retryTimer.stop();
			retryTimer.reset();
		}
		onConnectedSignal.dispatch(this);
		while ( notConnectedBuffer.length > 0) {
			var namedData: NamedData = notConnectedBuffer.shift();
			sendObjectWithType(uint(namedData.name), namedData.content);
		}
	}


	private function onSocketClose(event: Event): void {
		Log.info('EasySocket -> onSocketClose()');
		onClosedSignal.dispatch(this);
		if( keepAlive ) {
			connect(_remoteHost, _remotePort, keepAlive);
		}
	}


	private function onSocketError(event: IOErrorEvent): void {
		Log.info('EasySocket -> onSocketError()');
		onIOErrorSignal.dispatch(this, event);
	}

}
}
