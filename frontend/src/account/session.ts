import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { getSession, request, type User } from "../api.ts";

// A sessão (quem está logado e o token CSRF) fica guardada pelo TanStack Query: todas as
// telas leem dela, e entrar ou sair manda buscar de novo.
const SESSION_KEY = ["session"];

export function useSession() {
  return useQuery({ queryKey: SESSION_KEY, queryFn: getSession, staleTime: 5 * 60 * 1000 });
}

function useRefreshSession() {
  const client = useQueryClient();
  return () => client.invalidateQueries({ queryKey: SESSION_KEY });
}

export function useLogIn() {
  const refresh = useRefreshSession();
  return useMutation({
    mutationFn: (form: { email: string; password: string }) =>
      request<{ user: User }>("POST", "/api/session", form),
    onSuccess: refresh,
  });
}

type SignUpForm = {
  email: string;
  password: string;
  nickname: string;
  birth_date: string;
  terms_accepted: boolean;
};

export function useSignUp() {
  const refresh = useRefreshSession();
  return useMutation({
    mutationFn: (form: SignUpForm) => request<{ user: User }>("POST", "/api/registrations", form),
    onSuccess: refresh,
  });
}

export function useLogOut() {
  const refresh = useRefreshSession();
  return useMutation({ mutationFn: () => request("DELETE", "/api/session"), onSuccess: refresh });
}
