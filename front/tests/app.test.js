import { assertEqual, assertIncludes, assertTrue, test, waitFor } from "./runner.js";
import { mountApp } from "./helpers.js";

const catan = { id: "g1", title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90, isAvailable: true };
const dixit = { id: "g2", title: "Dixit", minPlayers: 3, maxPlayers: 6, durationMinutes: 30, isAvailable: false };
const camille = { id: "m1", name: "Camille", email: "camille@example.com" };
const mabel = {id: "m2", name: "Mabel", email: "mabel@example.com" };

const cardOf = (app, title) => app.$$("#games-list .card").find((card) => card.querySelector("h3").textContent === title);
const memberRowOf = (app, name) => app.$$("#members-list .row").find((row) => row.querySelector("strong").textContent === name);

// --- Jeux

test("games list shows one card per game with its availability", async () => {
  const app = await mountApp({ "GET /games": [catan, dixit] });
  await waitFor(() => app.$$("#games-list .card").length === 2, "deux cartes de jeu");
  assertIncludes(cardOf(app, "Catan").textContent, "Disponible");
  assertIncludes(cardOf(app, "Dixit").textContent, "Emprunté");
  assertIncludes(cardOf(app, "Catan").textContent, "3 à 4 joueur·ses · 90 min");
});

test("only an available game offers Borrow", async () => {
  const app = await mountApp({ "GET /games": [catan, dixit] });
  await waitFor(() => app.$$("#games-list .card").length === 2);
  const labels = (title) => [...cardOf(app, title).querySelectorAll("button")].map((button) => button.textContent);
  assertTrue(labels("Catan").includes("Emprunter"), "Catan devrait proposer Emprunter");
  assertTrue(!labels("Dixit").includes("Emprunter"), "Dixit est emprunté, il ne doit pas proposer Emprunter");
});

test("with no game, a message invites to add one", async () => {
  const app = await mountApp({ "GET /games": [] });
  await waitFor(() => !app.$("#games-empty").hidden);
  assertIncludes(app.$("#games-empty").textContent, "ne contient aucun jeu");
  assertIncludes(app.$("#games-empty").textContent, "Ajouter un jeu");
});

test("adding a game posts the form then reloads the list", async () => {
  const app = await mountApp({ "GET /games": [catan], "POST /games": [201, { ...catan, id: "g3", title: "Dixit" }] });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Ajouter un jeu");
  const form = app.$("#game-form");
  form.elements.title.value = "  Dixit ";
  form.elements.minPlayers.value = "3";
  form.elements.maxPlayers.value = "6";
  form.elements.durationMinutes.value = "30";
  form.requestSubmit();
  await waitFor(() => app.calls.some((call) => call.method === "POST" && call.path === "/games"), "l'appel POST /games");
  assertEqual(app.calls.find((call) => call.method === "POST").body, {
    title: "Dixit",
    minPlayers: 3,
    maxPlayers: 6,
    durationMinutes: 30,
  });
  await waitFor(() => !app.$("#game-dialog").open, "la boîte se ferme");
});

test("modify a game - send and update and reload list", async () => {
  let games = [catan];

  const app = await mountApp({
    "GET /games": () => games,
    "PUT /games/g1": (call) => {
      games = [{ ...games[0], ...call.body }];
      return games[0];
    },
  });

  await waitFor(() => app.$$("#games-list .card").length === 1);
  const card = cardOf(app, "Catan");

  app.click("Modifier", card);

  await waitFor(() => app.$("#game-dialog").open, "");
  const form = app.$("#game-form");
  assertEqual(form.elements.title.value, "Catan");
  assertEqual(form.elements.minPlayers.value, "3");

  form.elements.title.value = "Catan 2";
  form.requestSubmit();

  await waitFor(() => app.calls.some((call) => call.method === "PUT" && call.path === "/games/g1"), "");
  assertEqual(app.calls.find((call) => call.method === "PUT").body, {
    title: "Catan 2",
    minPlayers: 3,
    maxPlayers: 4,
    durationMinutes: 90,
  });
  await waitFor(() => cardOf(app, "Catan 2"), "");
  assertTrue(!app.$("#game-dialog").open, "");
});

test("delete removes a game and shows toast", async () => {
  let games = [catan]

  const app = await mountApp({
    "GET /games": () => games,
    "DELETE /games/g1": () => {
      games = [];
      return [204];
    },
  });
  
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.win.confirm = () => true
  app.click("Supprimer", cardOf(app, "Catan"));

  await waitFor(() => app.$$("#games-list .card").length === 0);
  assertIncludes(app.$("#toasts").textContent, "Catan a été supprimé");

});

test("delete fails and shows and error", async () => {
  let games = [dixit]

  const app = await mountApp({
    "GET /games": () => games,
    "DELETE /games/g2": [
      409,
      { error: true, reason: "A game with loans cannot be deleted" },
    ],
  });
  
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.win.confirm = () => true
  app.click("Supprimer", cardOf(app, "Dixit"));

  await waitFor(
    () => 
      app.$("#toasts").textContent.includes("Suppression impossible : ce jeu a un historique d'emprunts"));
});

test("a validation error is shown in French and the dialog stays open", async () => {
  const app = await mountApp({
    "GET /games": [],
    "POST /games": [400, { error: true, reason: "title is empty, durationMinutes is less than minimum of 1" }],
  });
  await waitFor(() => !app.$("#games-empty").hidden, "la page est chargée");
  app.click("Ajouter un jeu");
  app.$("#game-form").requestSubmit();
  await waitFor(() => !app.$("#game-dialog .form-error").hidden, "le message d'erreur");
  assertEqual(app.$("#game-dialog .form-error").textContent, "Le titre est obligatoire. La durée doit être d'au moins 1.");
  assertTrue(app.$("#game-dialog").open, "la boîte devrait rester ouverte");
});

// --- Emprunts

test("borrowing a game sends the game and the chosen member", async () => {
  const app = await mountApp({
    "GET /games": [catan],
    "GET /members": [camille],
    "POST /loans": [201, { id: "l1", gameID: "g1", memberID: "m1", borrowedAt: new Date().toISOString(), dueAt: new Date().toISOString() }],
  });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Emprunter", cardOf(app, "Catan"));
  await waitFor(() => app.$("#borrow-dialog").open, "la boîte d'emprunt");
  app.$("#borrow-form").requestSubmit();
  await waitFor(() => app.calls.some((call) => call.method === "POST" && call.path === "/loans"), "l'appel POST /loans");
  assertEqual(app.calls.find((call) => call.path === "/loans").body, { gameID: "g1", memberID: "m1" });
  await waitFor(() => app.$("#toasts").textContent.includes("emprunté"), "le message de confirmation");
});

test("borrowing without any member explains that one must be added first", async () => {
  const app = await mountApp({ "GET /games": [catan], "GET /members": [] });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Emprunter", cardOf(app, "Catan"));
  await waitFor(() => app.$("#toasts").textContent.includes("Ajoutez d'abord"), "le message d'aide");
  assertTrue(!app.$("#borrow-dialog").open, "la boîte d'emprunt ne doit pas s'ouvrir");
});

// --- Adhérent·es

test("members tab lists the members", async () => {
  const app = await mountApp({ "GET /members": [camille] }, { hash: "#members" });
  await waitFor(() => app.$$("#members-list .row").length === 1);
  assertIncludes(app.$("#members-list .row").textContent, "Camille");
  assertIncludes(app.$("#members-list .row").textContent, "camille@example.com");
});

test("with no member, a message invites to add one", async () => {
  const app = await mountApp({ "GET /members": [] }, { hash: "#members" });
  await waitFor(() => !app.$("#members-empty").hidden);
  assertIncludes(app.$("#members-empty").textContent, "Ajouter un·e adhérent·e");
});

test("adding a member posts the form", async () => {
  const app = await mountApp({ "GET /members": [], "POST /members": [201, camille] }, { hash: "#members" });
  await waitFor(() => !app.$("#members-empty").hidden);
  app.click("Ajouter un·e adhérent·e");
  const form = app.$("#member-form");
  form.elements.name.value = " Camille ";
  form.elements.email.value = "camille@example.com";
  form.requestSubmit();
  await waitFor(() => app.calls.some((call) => call.method === "POST" && call.path === "/members"), "l'appel POST /members");
  assertEqual(app.calls.find((call) => call.method === "POST").body, { name: "Camille", email: "camille@example.com" });
});

test("modify a member - send and update and reload list", async () => {
  let members = [camille];

  const app = await mountApp({
    "GET /members": () => members,
    "PUT /members/m1": (call) => {
      members = [{ ...members[0], ...call.body }];
      return members[0];
    },
  },{ hash: "#members" },
  );

  await waitFor(() => app.$$("#members-list .row").length === 1);
  const row = memberRowOf(app, "Camille");

  app.click("Modifier", row);

  await waitFor(() => app.$("#member-dialog").open, "");
  const form = app.$("#member-form");
  assertEqual(form.elements.name.value, "Camille");

  form.elements.name.value = "Camille la Belle";
  form.requestSubmit();

  await waitFor(() => app.calls.some((call) => call.method === "PUT" && call.path === "/members/m1"), "");
  assertEqual(app.calls.find((call) => call.method === "PUT").body, {
    name: "Camille la Belle",
    email: "camille@example.com",
  });
  await waitFor(() => memberRowOf(app, "Camille la Belle"), "");
  assertTrue(!app.$("#member-dialog").open, "");
});

test("delete removes a member and shows toast", async () => {
  let members = [camille]

  const app = await mountApp({
    "GET /members": () => members,
    "DELETE /members/m1": () => {
      members = [];
      return [204];
    },
    },{ hash: "#members" },
  );
  
  await waitFor(() => app.$$("#members-list .row").length === 1);
  app.win.confirm = () => true
  app.click("Supprimer", memberRowOf(app, "Camille"));

  await waitFor(() => app.$$("#members-list .row").length === 0);
  assertIncludes(app.$("#toasts").textContent, "Camille a été supprimé.");
});

test("delete member fails and shows an error", async () => {
  let members = [mabel];

  const app = await mountApp({
    "GET /members": () => members,
    "DELETE /members/m2": [
      409,
      { error: true, reason: "A member with loans cannot be deleted" },
      ],
    },{ hash: "#members" },
  );
  
  await waitFor(() => app.$$("#members-list .row").length === 1);
  app.win.confirm = () => true
  app.click("Supprimer", memberRowOf(app, "Mabel"));

  await waitFor(
    () => 
      app.$("#toasts").textContent.includes("Suppression impossible : cet·te adhérent·e a un historique d'emprunts, conservé même quand tout est rendu."));
});

test("an email already in use is shown in French", async () => {
  const app = await mountApp(
    { "GET /members": [], "POST /members": [409, { error: true, reason: "A member with this email already exists" }] },
    { hash: "#members" },
  );
  await waitFor(() => !app.$("#members-empty").hidden);
  app.click("Ajouter un·e adhérent·e");
  app.$("#member-form").requestSubmit();
  await waitFor(() => !app.$("#member-dialog .form-error").hidden, "le message d'erreur");
  assertIncludes(app.$("#member-dialog .form-error").textContent, "utilise déjà cette adresse e-mail");
});
