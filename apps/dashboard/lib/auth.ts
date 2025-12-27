export function requireAuth() {
  if (typeof window === 'undefined') return;
  const token = localStorage.getItem('accessToken');
  if (!token) window.location.href = '/login';
}
