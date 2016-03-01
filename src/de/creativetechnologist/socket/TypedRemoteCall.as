/**
 * Created by mak on 28/01/16.
 */
package de.creativetechnologist.socket {
import flash.events.TimerEvent;
import flash.utils.Timer;
import flash.utils.getTimer;

import org.osflash.signals.Signal;

public class TypedRemoteCall {

	public var socket: TypedTCPSocket;
	public var sendType: uint;
	public var signal: Signal = new Signal(TypedRemoteCall, Object);

	public var success: Boolean;
	public var delay: int;
	private var timer: Timer;
	private var startTime: int = 0;


	public function TypedRemoteCall(socket: TypedTCPSocket, sendType: uint, data: * = null, msTimeout: int = 2000) {
		startTime = getTimer();
		this.socket = socket;
		this.sendType = sendType;
		timer = new Timer(msTimeout, 1);
		timer.addEventListener(TimerEvent.TIMER_COMPLETE, onTimerComplete);

		var time: uint = uint(new Date().time);
//		trace( 'TypedRemoteCall -> TypedRemoteCall: ', time );
		socket.addListenerForType(time, onCallback);
		var sendData = {};
		sendData['requestId'] = time;
		sendData['data'] = data;

		socket.sendObject(sendData, sendType);
		timer.start();
	}

	private function onTimerComplete(event: TimerEvent): void {
		trace( 'TypedRemoteCall -> onTimerComplete: TIMEOUT!!!' );
		disposeTimer();
		success = false;
		signal.dispatch(this, null);
		dispose();
	}

	public function dispose() {
		if( !timer )
			return;
		disposeTimer();
		socket.removeListenerForType(sendType, onCallback);
		signal.removeAll();
	}

	private function disposeTimer(): void {
		if( !timer )
			return;
		timer.stop();
		timer.removeEventListener(TimerEvent.TIMER_COMPLETE, onTimerComplete);
		timer = null;
	}

	private function onCallback(target: TypedTCPSocket, data: *, type: int): void {
		disposeTimer();
		success = true;
		socket.removeListenerForType(sendType, onCallback);
		delay = getTimer() - startTime;
		signal.dispatch(this, data);
		signal.removeAll();
		dispose();
	}
}
}
