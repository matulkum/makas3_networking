/**
 * Created by mak on 19.02.15.
 */
package de.creativetechnologist.modem {

/**
 * Contains script from: https://gerrybeauregard.wordpress.com/2010/08/06/real-time-spectrum-analysis/
 *
 * Here is the license text:
 *
 * A real-time spectrum analyzer.
 *
 * Released under the MIT License
 *
 * Copyright (c) 2010 Gerald T. Beauregard
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */


import de.creativetechnologist.log.Log;

import flash.events.SampleDataEvent;
import flash.media.Microphone;
import flash.utils.setInterval;

import gerrybeauregard.FFT2;

import org.osflash.signals.Signal;

public class AudiojackReceiver {

	private var microphone: Microphone;
	private var triggerDB: Number;

	private const SAMPLE_RATE:Number = 22050;   // Actual microphone sample rate (Hz)
	private const LOGN:uint = 11;               // Log2 FFT length

	private const N:uint = 1 << LOGN;         // FFT Length
	private const BUF_LEN:uint = N;             // Length of buffer for mic audio

	private var m_fft: FFT2;
	private var m_tempRe: Vector.<Number>;
	private var m_tempIm: Vector.<Number>;
	private var m_mag: Vector.<Number>;
	private var m_freq: Vector.<Number>;
	private var m_win: Vector.<Number>;
	private var m_buf: Vector.<Number>;

	private var m_writePos:uint = 0;            // Position to write new audio from mic

	private var freqIndizesToListen: Vector.<uint>;
	// [(this, freqIndex:int, on:Boolean)]
	private var freqSignals: Vector.<AudioFrequencySignal>;


	public function AudiojackReceiver(microphone: Microphone, triggerDB: Number = -20) {

		this.triggerDB = triggerDB;
		var i: uint;

		// Set up the FFT
		m_fft = new FFT2();
		m_fft.init(LOGN);
		m_tempRe = new Vector.<Number>(N);
		m_tempIm = new Vector.<Number>(N);
		m_mag = new Vector.<Number>(N / 2);
		//m_smoothMag = new Vector.<Number>(N/2);

		// Vector with frequencies for each bin number. Used
		// in the graphing code (not in the analysis itself).
		m_freq = new Vector.<Number>(N / 2);
		for (i = 0; i < N / 2; i++)
			m_freq[i] = i * SAMPLE_RATE / N;

		// Hanning analysis window
		m_win = new Vector.<Number>(N);
		for (i = 0; i < N; i++)
			m_win[i] = (4.0 / N) * 0.5 * (1 - Math.cos(2 * Math.PI * i / N));

		// Create a buffer for the input audio
		m_buf = new Vector.<Number>(BUF_LEN);
		for (i = 0; i < BUF_LEN; i++)
			m_buf[i] = 0.0;

		// Set up microphone input
		microphone = microphone;
		microphone.rate = SAMPLE_RATE / 1000;
		microphone.setSilenceLevel(0.0);         // Have the mic run non-stop, regardless of the input level
		microphone.addEventListener(SampleDataEvent.SAMPLE_DATA, onMicSampleData);

		// Set up a timer to do periodic updates of the spectrum
//		m_timer = new Timer(UPDATE_PERIOD);
//		m_timer.addEventListener(TimerEvent.TIMER, updateSpectrum);
//		m_timer.start();

		freqIndizesToListen = new <uint>[];
		freqSignals = new <AudioFrequencySignal>[];
	}


	public function addListenerToFreqIndex(index: uint): AudioFrequencySignal {
		var signal: AudioFrequencySignal;
		var vectorIndex: Number = freqIndizesToListen.indexOf(index);
		if( vectorIndex < 0) {
			freqIndizesToListen.push(index);
			signal = new AudioFrequencySignal(index);
			freqSignals.push(signal);
		}
		else
			signal = freqSignals[vectorIndex];

		return signal;
	}

	//TODO addListenerToFreqIndex(index: uint)


	private function onMicSampleData( event:SampleDataEvent ):void
	{
		// Get number of available input samples
		var len:uint = event.data.length/4;

		// Read the input data and stuff it into
		// the circular buffer
		for ( var i:uint = 0; i < len; i++ )
		{
			m_buf[m_writePos] = event.data.readFloat();
			m_writePos = (m_writePos+1)%BUF_LEN;
		}
		update();
	}


	public function update( ):void
	{
		// Copy data from circular microphone audio
		// buffer into temporary buffer for FFT, while
		// applying Hanning window.
		var i:int;
		var length: int;
		var pos:uint = m_writePos;
		for ( i = 0; i < N; i++ )
		{
			m_tempRe[i] = m_win[i]*m_buf[pos];
			pos = (pos+1)%BUF_LEN;
		}

		// Zero out the imaginary component
		for ( i = 0; i < N; i++ )
			m_tempIm[i] = 0.0;

		// Do FFT and get magnitude spectrum
		m_fft.run( m_tempRe, m_tempIm );
		for ( i = 0; i < N/2; i++ )
		{
			var re:Number = m_tempRe[i];
			var im:Number = m_tempIm[i];
			m_mag[i] = Math.sqrt(re*re + im*im);
		}

		// Convert to dB magnitude
		const SCALE:Number = 20/Math.LN10;
		for ( i = 0; i < N/2; i++ )
		{
			// 20 log10(mag) => 20/ln(10) ln(mag)
			// Addition of MIN_VALUE prevents log from returning minus infinity if mag is zero
			m_mag[i] = SCALE*Math.log( m_mag[i] + Number.MIN_VALUE );
		}


		length = freqIndizesToListen.length;
		for(i = 0; i < length; i++) {

			if( m_mag[freqIndizesToListen[i]] > triggerDB)
				freqSignals[i].isOn = true;
			else
				freqSignals[i].isOn = false;
		}

	}



}


}
