import { api, ApiError, translateError } from "../api.js";
import { assertEqual, assertIncludes, assertTrue, test } from "./runner.js";
import { fakeApi, withFakeFetch } from "./helpers.js";

// --- translateError : les messages de l'API deviennent des phrases en français

test("translateError translates a known message", () => {
  assertEqual(translateError(409, "Game is already on loan"), "Ce jeu est déjà emprunté : il faut d'abord le rendre.");
});

test("translateError translates each validation error separately", () => {
  const message = translateError(400, "title is empty, minPlayers is less than minimum of 1");
  assertEqual(message, "Le titre est obligatoire. Le nombre minimum de joueur·ses doit être d'au moins 1.");
});

test("translateError translates a missing field and an invalid email", () => {
  assertEqual(translateError(400, "name is required"), "Le nom est obligatoire.");
  assertIncludes(translateError(400, "email is not a valid email address"), "adresse e-mail n'est pas valide");
});

test("translateError never lets unknown English through", () => {
  assertEqual(translateError(409, "Something unexpected"), "Cette action est impossible dans l'état actuel des données.");
  assertEqual(translateError(500, "boom"), "Le serveur a rencontré une erreur. Réessayez dans un instant.");
  assertEqual(translateError(418, "teapot"), "Une erreur est survenue. Réessayez.");
});

// --- requêtes envoyées à l'API

test("listGames calls GET /games", async () => {
  const { fetch, calls } = fakeApi({ "GET /games": [] });
  await withFakeFetch(fetch, () => api.listGames());
  assertEqual(`${calls[0].method} ${calls[0].path}`, "GET /games");
});

test("createGame sends a JSON POST", async () => {
  const { fetch, calls } = fakeApi({ "POST /games": [201, { id: "1" }] });
  const game = { title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90 };
  const created = await withFakeFetch(fetch, () => api.createGame(game));
  assertEqual(calls[0].method, "POST");
  assertEqual(calls[0].body, game);
  assertEqual(created.id, "1");
});

test("updateGame sends a JSON PUT", async () => {
  const { fetch, calls } = fakeApi({ "PUT /games/1": [200, { id: "1", title: "Catan 2" }] });

  const change = { title: "Catan 2", minPlayers: 3, maxPlayers: 4, durationMinutes: 90 };

  const updated = await withFakeFetch(fetch, () => api.updateGame("1", change));

  assertEqual(calls[0].method, "PUT");
  assertEqual(calls[0].path, "/games/1");
  assertEqual(calls[0].body, change);
  assertEqual(updated.title, "Catan 2");
});

test("borrow sends the game and the member", async () => {
  const { fetch, calls } = fakeApi({ "POST /loans": [201, { id: "l1" }] });
  await withFakeFetch(fetch, () => api.borrow("g1", "m1"));
  assertEqual(calls[0].body, { gameID: "g1", memberID: "m1" });
});

test("deleteGame sends DELETE and deletes a game", async () => {
  const { fetch, calls} = fakeApi({ "DELETE /games/1": [204] });

  const deleted = await withFakeFetch(fetch, () => api.deleteGame("1"));

  assertEqual(calls[0].method, "DELETE");
  assertEqual(calls[0].path, "/games/1");
  assertEqual(deleted, null);
})

test("createMember sends a JSON POST", async () => {
  const { fetch, calls } = fakeApi({ "POST /members": [201, { id: "1" }] });
  const member = { name: "Name", email: "email@email.fr" };
  const created = await withFakeFetch(fetch, () => api.createMember(member));
  assertEqual(calls[0].method, "POST");
  assertEqual(calls[0].body, member);
  assertEqual(created.id, "1");
});

test("updateMember sends a JSON PUT", async () => {
  const { fetch, calls } = fakeApi({ "PUT /members/1": [200, { id: "1", name: "Name" }] });

  const change = { name: "Name" };

  const updated = await withFakeFetch(fetch, () => api.updateMember("1", change));

  assertEqual(calls[0].method, "PUT");
  assertEqual(calls[0].path, "/members/1");
  assertEqual(calls[0].body, change);
  assertEqual(updated.name, "Name");
});

test("deleteMember sends DELETE and deletes a member", async () => {
  const { fetch, calls} = fakeApi({ "DELETE /members/1": [204] });

  const deleted = await withFakeFetch(fetch, () => api.deleteMember("1"));

  assertEqual(calls[0].method, "DELETE");
  assertEqual(calls[0].path, "/members/1");
  assertEqual(deleted, null);
})

test("return Loan returns ok and LoanDTO", async () => {
  const loanFake = { id: "1", gameID: "g1", memberID: "m1", returnedAt: "now"};
  const { fetch, calls } = fakeApi({ "POST /loans/1/return": [200, loanFake] });

  const res = await withFakeFetch(fetch, () => api.returnLoan("1"));
  assertEqual(calls[0].method, "POST");
  assertEqual(calls[0].path, "/loans/1/return");
  assertEqual(calls[0].body, undefined);
  assertEqual(res.id, "1");
  assertEqual(res.returnedAt != null, true);
})

test("gets member loans and returns ok and array of LoanDTO", async () => {
  const loanArrayFake = [
    { id: "1", gameID: "g1", memberID: "m1", returnedAt: "now"},
    { id: "2", gameID: "g2", memberID: "m1", returnedAt: "now"},
  ];

  const { fetch, calls } = fakeApi({ "GET /members/1/loans": [200, loanArrayFake] });
  const res = await withFakeFetch(fetch, () => api.memberLoans("1"));
  assertEqual(calls[0].method, "GET");
  assertEqual(calls[0].path, "/members/1/loans");
  assertEqual(res.length , 2);
  assertEqual(res[0].id , "1");
})

test("gets member without loans and returns ok and empty array", async () => {
  const loanArrayFake = [];

  const { fetch, calls } = fakeApi({ "GET /members/1/loans": [200, loanArrayFake] });
  const res = await withFakeFetch(fetch, () => api.memberLoans("1"));
  assertEqual(calls[0].method, "GET");
  assertEqual(calls[0].path, "/members/1/loans");
  assertEqual(res.length , 0);
})

// --- erreurs

// Attend qu'une promesse échoue et renvoie l'erreur (échoue si elle réussit).
async function expectError(promise) {
  try {
    await promise;
  } catch (error) {
    return error;
  }
  throw new Error("une erreur était attendue");
}

test("an unreachable server gives a clear message", async () => {
  const unreachable = async () => {
    throw new TypeError("Failed to fetch");
  };
  const error = await expectError(withFakeFetch(unreachable, () => api.listGames()));
  assertEqual(error.status, 0);
  assertIncludes(error.message, "Impossible de joindre le serveur");
});

test("a game already on loan (409) gives a French message", async () => {
  const { fetch } = fakeApi({ "POST /loans": [409, { error: true, reason: "Game is already on loan" }] });
  const error = await expectError(withFakeFetch(fetch, () => api.borrow("g1", "m1")));
  assertTrue(error instanceof ApiError, "l'erreur devrait être une ApiError");
  assertEqual(error.status, 409);
  assertEqual(error.message, "Ce jeu est déjà emprunté : il faut d'abord le rendre.");
});
