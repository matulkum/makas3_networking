/**
 * Created by mak on 20.08.14.
 */
package de.creativetechnolgist.socket {
import de.creativetechnolgist.log.Log;

import flash.errors.IOError;
import flash.events.ServerSocketConnectEvent;
import flash.net.ServerSocket;
import flash.net.Socket;
import flash.utils.Dictionary;

import org.osflash.signals.Signal;

public class SignalServerSocket {

	private var localPort: int;

	private var serverSocket: ServerSocket;
	private var clientSockets: Vector.<EasySocket>;

	private var type2globalListenerSignals = Dictionary;


//	private var type2HandlerVectors: Dictionary;

	private var isInit: Boolean = false;

	public function SignalServerSocket() {
		type2globalListenerSignals = new Dictionary();
	}

	//TODO dispose


	public function init(localPort: int): void {
		if( isInit ) return;
		isInit = true;

		this.localPort = localPort;

		Log.info('SignalSocketServer -> init()');

		clientSockets = new <EasySocket>[];

		serverSocket = new ServerSocket();
		serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onServerSocketConnect);
		serverSocket.bind(localPort);
		serverSocket.listen();
	}


	public function addGlobalListener(type: uint, handler: Function): void {

		var signal : Signal = type2globalListenerSignals[type] as Signal;
		if( !signal ) {
			signal = new Signal();
			type2globalListenerSignals[type] = signal;
		}
		signal.add(handler);
	}


	public function removeGlobalListener(type: String, handler: Function): void {

		var signal : Signal = type2globalListenerSignals[type] as Signal;
		if( signal ) {
			signal.remove(handler);
			//TODO remove signal if not needed andymore??
		}
	}


	private function addClientSocket(socket: Socket): EasySocket {
		var easySocket: EasySocket = new EasySocket(socket);
		easySocket.onConnectedSignal.add(onEasySocketConnected);
		easySocket.onClosedSignal.add(onEasySocketClosed);
		easySocket.onIOErrorSignal.add(onEasySocketIOError);
		easySocket.onObjectReceived.add(onEasySocketObjectTypeReceived);

		clientSockets.push(easySocket);

		Log.info('SignalSocketServer -> addClientSocket(): ', socket.toString());
		return easySocket;
	}


	//TODO also disconnect??
	private function removeClientSocket(easySocket: EasySocket): void {
		var index: int = clientSockets.indexOf(easySocket);
		if( index > -1) {
			clientSockets.splice(index, 1);
		}
		easySocket.dispose();
	}


	private function onServerSocketConnect(event: ServerSocketConnectEvent): void {
		addClientSocket(event.socket);
	}


	private function onEasySocketConnected(target: EasySocket): void {
	}


	private function onEasySocketClosed(target: EasySocket): void {
		removeClientSocket(target);
	}


	private function onEasySocketIOError(target: EasySocket, error: IOError): void {
		trace('SignalServerSocket -> onEasySocketIOError()', error.toString());
	}


	private function onEasySocketObjectTypeReceived(target: EasySocket, type: uint, data: Object): void {
		var signal : Signal = type2globalListenerSignals[type] as Signal;
		if( signal )
			signal.dispatch(target, type, data);
	}

}
}
