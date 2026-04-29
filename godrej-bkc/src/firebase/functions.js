import { functions } from './config';
import { httpsCallable } from 'firebase/functions';

export const createRetrievalRequest = httpsCallable(functions, 'createRetrievalRequest');
export const markVehicleReady = httpsCallable(functions, 'markVehicleReady');
