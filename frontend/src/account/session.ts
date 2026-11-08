import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { getSession, request } from "../api.ts";

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

export function useLogOut() {
  const refresh = useRefreshSession();
  return useMutation({ mutationFn: () => request("DELETE", "/api/session"), onSuccess: refresh });
}
