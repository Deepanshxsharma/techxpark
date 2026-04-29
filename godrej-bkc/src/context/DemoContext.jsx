import React, { createContext, useContext } from 'react';
import useSimulation from '../hooks/useSimulation';

const DemoContext = createContext();

export const useDemo = () => useContext(DemoContext);

/**
 * DemoProvider — wraps the simulation engine hook and exposes it to the entire app.
 */
export const DemoProvider = ({ children }) => {
  const simulation = useSimulation();

  return (
    <DemoContext.Provider value={simulation}>
      {children}
    </DemoContext.Provider>
  );
};
