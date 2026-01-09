// Voice input hook using Web Speech API
// Implements push-to-talk with real-time transcription

import { useState, useRef, useCallback, useEffect } from 'react';

// Web Speech API types
interface SpeechRecognitionEvent extends Event {
  results: SpeechRecognitionResultList;
  resultIndex: number;
}

interface SpeechRecognitionErrorEvent extends Event {
  error: string;
  message: string;
}

interface SpeechRecognition extends EventTarget {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  start: () => void;
  stop: () => void;
  abort: () => void;
  onresult: ((event: SpeechRecognitionEvent) => void) | null;
  onerror: ((event: SpeechRecognitionErrorEvent) => void) | null;
  onend: (() => void) | null;
  onstart: (() => void) | null;
}

declare global {
  interface Window {
    SpeechRecognition: new () => SpeechRecognition;
    webkitSpeechRecognition: new () => SpeechRecognition;
  }
}

export type VoiceInputState =
  | 'idle'           // Not recording
  | 'recording'      // Recording in progress
  | 'processing'     // Processing final result
  | 'cancelled';     // User cancelled

export interface UseVoiceInputOptions {
  /** Language for recognition (default: 'zh-CN') */
  lang?: string;
  /** Callback when final transcript is ready */
  onResult?: (transcript: string) => void;
  /** Callback when recording starts */
  onStart?: () => void;
  /** Callback when recording ends */
  onEnd?: () => void;
  /** Callback on error */
  onError?: (error: string) => void;
}

export interface UseVoiceInputReturn {
  /** Current state of voice input */
  state: VoiceInputState;
  /** Whether voice input is supported in this browser */
  isSupported: boolean;
  /** Interim transcript (while speaking) */
  interimTranscript: string;
  /** Final transcript (after speech ends) */
  finalTranscript: string;
  /** Start recording */
  startRecording: () => void;
  /** Stop recording and get result */
  stopRecording: () => void;
  /** Cancel recording without result */
  cancelRecording: () => void;
  /** Clear transcripts */
  clearTranscript: () => void;
}

export function useVoiceInput(options: UseVoiceInputOptions = {}): UseVoiceInputReturn {
  const { lang = 'zh-CN' } = options;

  const [state, setState] = useState<VoiceInputState>('idle');
  const [interimTranscript, setInterimTranscript] = useState('');
  const [finalTranscript, setFinalTranscript] = useState('');

  // Use refs to avoid stale closures
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const isCancelledRef = useRef(false);
  const stateRef = useRef<VoiceInputState>('idle');
  const transcriptRef = useRef({ interim: '', final: '' });

  // Store callbacks in ref to avoid re-creating recognition on callback change
  const callbacksRef = useRef(options);
  useEffect(() => {
    callbacksRef.current = options;
  });

  // Keep stateRef in sync
  useEffect(() => {
    stateRef.current = state;
  }, [state]);

  // Check if Web Speech API is supported
  const isSupported = typeof window !== 'undefined' &&
    ('SpeechRecognition' in window || 'webkitSpeechRecognition' in window);

  // Initialize speech recognition - only depends on isSupported and lang
  useEffect(() => {
    if (!isSupported) return;

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    const recognition = new SpeechRecognition();

    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = lang;

    recognition.onstart = () => {
      setState('recording');
      callbacksRef.current.onStart?.();
    };

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      let interim = '';
      let final = transcriptRef.current.final;

      for (let i = event.resultIndex; i < event.results.length; i++) {
        const transcript = event.results[i][0].transcript;
        if (event.results[i].isFinal) {
          final += transcript;
        } else {
          interim += transcript;
        }
      }

      // Update both ref and state
      transcriptRef.current = { interim, final };
      setFinalTranscript(final);
      setInterimTranscript(interim);
    };

    recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      console.error('Speech recognition error:', event.error);

      // Don't treat 'no-speech' or 'aborted' as errors
      if (event.error !== 'no-speech' && event.error !== 'aborted') {
        callbacksRef.current.onError?.(event.error);
      }

      setState('idle');
    };

    recognition.onend = () => {
      if (!isCancelledRef.current && stateRef.current === 'recording') {
        setState('processing');
        // Give a small delay for final results
        setTimeout(() => {
          setState('idle');
          callbacksRef.current.onEnd?.();
        }, 100);
      } else {
        setState('idle');
        callbacksRef.current.onEnd?.();
      }
    };

    recognitionRef.current = recognition;

    return () => {
      recognition.abort();
    };
  }, [isSupported, lang]);

  const startRecording = useCallback(() => {
    if (!recognitionRef.current || stateRef.current !== 'idle') return;

    isCancelledRef.current = false;
    transcriptRef.current = { interim: '', final: '' };
    setInterimTranscript('');
    setFinalTranscript('');

    try {
      recognitionRef.current.start();
    } catch (error) {
      console.error('Failed to start recording:', error);
      callbacksRef.current.onError?.('Failed to start recording');
    }
  }, []);

  const stopRecording = useCallback(() => {
    if (!recognitionRef.current || stateRef.current !== 'recording') return;

    isCancelledRef.current = false;
    recognitionRef.current.stop();

    // Use ref values instead of state to get the latest transcript
    setTimeout(() => {
      const { interim, final } = transcriptRef.current;
      const transcript = final + interim;
      if (transcript.trim()) {
        callbacksRef.current.onResult?.(transcript.trim());
      }
    }, 150);
  }, []);

  const cancelRecording = useCallback(() => {
    if (!recognitionRef.current) return;

    isCancelledRef.current = true;
    setState('cancelled');
    recognitionRef.current.abort();

    transcriptRef.current = { interim: '', final: '' };
    setInterimTranscript('');
    setFinalTranscript('');

    setTimeout(() => {
      setState('idle');
    }, 100);
  }, []);

  const clearTranscript = useCallback(() => {
    transcriptRef.current = { interim: '', final: '' };
    setInterimTranscript('');
    setFinalTranscript('');
  }, []);

  return {
    state,
    isSupported,
    interimTranscript,
    finalTranscript,
    startRecording,
    stopRecording,
    cancelRecording,
    clearTranscript,
  };
}
