'use client';

import { useEffect } from 'react';

export default function Home() {
  useEffect(() => {
    const token = localStorage.getItem('accessToken');
    window.location.href = token ? '/broker/leads/pending' : '/login';
  }, []);

  return null;
}
