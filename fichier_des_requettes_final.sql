-- Fichier SQL finale contenant toutes les requêtes demandées pour BiblioTecho dans le cadre du projet


-- 1. Trigger pour mettre à jour le nombre total d'exemplaires après ajout/suppression
DELIMITER //
DROP TRIGGER IF EXISTS after_exemplaire_insert //
CREATE TRIGGER after_exemplaire_insert
AFTER INSERT ON Exemplaire
FOR EACH ROW
BEGIN
    UPDATE Livre
    SET Nombre_total_exemplaires = Nombre_total_exemplaires + 1,
        Nombre_exemplaires_disponibles = Nombre_exemplaires_disponibles + 1
    WHERE Code_ISBN = NEW.Code_ISBN_exm;
END //
DELIMITER ;

DELIMITER //
DROP TRIGGER IF EXISTS after_exemplaire_delete //
CREATE TRIGGER after_exemplaire_delete
AFTER DELETE ON Exemplaire
FOR EACH ROW
BEGIN
    UPDATE Livre
    SET Nombre_total_exemplaires = Nombre_total_exemplaires - 1,
        Nombre_exemplaires_disponibles = Nombre_exemplaires_disponibles - 1
    WHERE Code_ISBN = OLD.Code_ISBN_exm;
END //
DELIMITER ;

-- 2. Trigger pour mettre à jour le nombre d'exemplaires disponibles à chaque emprunt/retour
DELIMITER //
DROP TRIGGER IF EXISTS after_emprunt_insert //
CREATE TRIGGER after_emprunt_insert
AFTER INSERT ON Emprunt
FOR EACH ROW
BEGIN
    UPDATE Exemplaire
    SET Statut = 'emprunté'
    WHERE Code_exemplaire = NEW.Code_exemplaire_emp;
    UPDATE Livre
    SET Nombre_exemplaires_disponibles = Nombre_exemplaires_disponibles - 1
    WHERE Code_ISBN = (SELECT Code_ISBN_exm FROM Exemplaire WHERE Code_exemplaire = NEW.Code_exemplaire_emp);
END //
DELIMITER ;

DELIMITER //
DROP TRIGGER IF EXISTS after_emprunt_update //
CREATE TRIGGER after_emprunt_update
AFTER UPDATE ON Emprunt
FOR EACH ROW
BEGIN
    IF NEW.Date_retour_effective IS NOT NULL AND OLD.Date_retour_effective IS NULL THEN
        UPDATE Exemplaire
        SET Statut = 'disponible'
        WHERE Code_exemplaire = NEW.Code_exemplaire_emp;
        UPDATE Livre
        SET Nombre_exemplaires_disponibles = Nombre_exemplaires_disponibles + 1
        WHERE Code_ISBN = (SELECT Code_ISBN_exm FROM Exemplaire WHERE Code_exemplaire = NEW.Code_exemplaire_emp);
    END IF;
END //
DELIMITER ;

-- 3. Trigger pour vérifier que le nombre d'emprunts n'excède pas 3
DELIMITER //
DROP TRIGGER IF EXISTS before_emprunt_insert_limit //
DROP TRIGGER IF EXISTS before_emprunt_insert_limit //
CREATE TRIGGER before_emprunt_insert_limit
BEFORE INSERT ON Emprunt
FOR EACH ROW
BEGIN
    DECLARE nombre_emprunts INT;
    SELECT COUNT(*) INTO nombre_emprunts
    FROM Emprunt
    WHERE Num_adherent_emp = NEW.Num_adherent_emp AND Date_retour_effective IS NULL;
    IF nombre_emprunts >= 3 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erreur : L\'adhérent a déjà 3 emprunts actifs.';
    END IF;
END //
DELIMITER ;

-- 4. Trigger pour vérifier qu'un adhérent n'emprunte pas plusieurs exemplaires du même livre
DELIMITER //
DROP TRIGGER IF EXISTS before_emprunt_insert_duplicate //
CREATE TRIGGER before_emprunt_insert_duplicate
BEFORE INSERT ON Emprunt
FOR EACH ROW
BEGIN
    DECLARE livre_deja_emprunte INT;
    SELECT COUNT(*) INTO livre_deja_emprunte
    FROM Emprunt e
    JOIN Exemplaire ex ON e.Code_exemplaire_emp = ex.Code_exemplaire
    WHERE e.Num_adherent_emp = NEW.Num_adherent_emp
    AND ex.Code_ISBN_exm = (SELECT Code_ISBN_exm FROM Exemplaire WHERE Code_exemplaire = NEW.Code_exemplaire_emp)
    AND e.Date_retour_effective IS NULL;
    IF livre_deja_emprunte > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erreur : L\'adhérent a déjà emprunté un exemplaire de ce livre.';
    END IF;
END //
DELIMITER ;

-- 5. Trigger pour vérifier les pénalités non payées avant un emprunt
DELIMITER //
DROP TRIGGER IF EXISTS before_emprunt_insert_penalite //
CREATE TRIGGER before_emprunt_insert_penalite
BEFORE INSERT ON Emprunt
FOR EACH ROW
BEGIN
    DECLARE penalites_non_payees INT;
    SELECT COUNT(*) INTO penalites_non_payees
    FROM penalite
    WHERE Num_adherent_pn = NEW.Num_adherent_emp AND Statut = 'non_payée';
    IF penalites_non_payees > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erreur : L\'adhérent a des pénalités non payées.';
    END IF;

END //
DELIMITER ;

-- 6. Transaction pour supprimer un exemplaire égaré
DELIMITER //
DROP PROCEDURE IF EXISTS SupprimerExemplaireEgare //
CREATE PROCEDURE SupprimerExemplaireEgare(
    IN p_code_exemplaire VARCHAR(20),
    IN p_num_adherent VARCHAR(10)
)
BEGIN
    DECLARE v_valeur DECIMAL(10,2);
    DECLARE v_code_isbn VARCHAR(13);
    START TRANSACTION;
    SELECT Code_ISBN_exm INTO v_code_isbn
    FROM Exemplaire
    WHERE Code_exemplaire = p_code_exemplaire;
    SELECT Valeur INTO v_valeur
    FROM Livre
    WHERE Code_ISBN = v_code_isbn;
    UPDATE Exemplaire
    SET Statut = 'perdu'
    WHERE Code_exemplaire = p_code_exemplaire;
    INSERT INTO Penalite (Num_adherent_pn, Id_emprunt_pn, Montant, Date_création, Statut, Type_penalite)
    VALUES (p_num_adherent, NULL, v_valeur, CURDATE(), 'non_payée', 'perte');
    DELETE FROM Exemplaire
    WHERE Code_exemplaire = p_code_exemplaire;
    COMMIT;
END //
DELIMITER ;

-- 7. Transaction pour enregistrer un retour et évaluer les pénalités
DELIMITER //
DROP PROCEDURE IF EXISTS EnregistrerRetour //
CREATE PROCEDURE EnregistrerRetour(
    IN p_id_emprunt INT,
    IN p_date_retour DATE
)
BEGIN
    DECLARE v_retard INT;
    DECLARE v_penalite DECIMAL(10,2);
    START TRANSACTION;
    UPDATE Emprunt
    SET Date_retour_effective = p_date_retour
    WHERE Id_emprunt = p_id_emprunt;
    SELECT DATEDIFF(p_date_retour, Date_retour_prévue) INTO v_retard
    FROM Emprunt
    WHERE Id_emprunt = p_id_emprunt;
    IF v_retard > 0 THEN
        SET v_penalite = v_retard * 500;
        INSERT INTO Penalite (Num_adherent_pn, Id_emprunt_pn, Montant, Date_creation, Statut, Type_penalite)
        SELECT Num_adherent_emp, p_id_emprunt, v_penalite, CURDATE(), 'non_payée', 'retard'
        FROM Emprunt
        WHERE Id_emprunt = p_id_emprunt;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- 8. Requête pour enregistrer le paiement d'une pénalité
UPDATE Penalite
SET Statut = 'payée'
WHERE Id_penalite = 1; -- Remplacer 1 par l'ID de la pénalité à mettre à jour

-- 9. Requête pour désactiver les abonnements expirés
UPDATE Abonnement
SET Statut = 'expiré'
WHERE Date_fin < CURDATE() AND Statut = 'actif';

-- 10. Requête pour mettre à jour les réservations
UPDATE Reservation r
JOIN Livre l ON r.Code_ISBN_re = l.Code_ISBN
SET r.Date_notification = CURDATE(),
    r.Date_expiration = DATE_ADD(CURDATE(), INTERVAL 3 DAY),
    r.Statut = 'notifiée'
WHERE r.Statut = 'en_attente'
AND l.Nombre_exemplaires_disponibles > 0
AND r.Id_reservation = (
    SELECT Id_reservation
    FROM Reservation
    WHERE Code_ISBN_re = r.Code_ISBN_re AND Statut = 'en_attente'
    ORDER BY Date_reservation ASC
    LIMIT 1
);

-- 11. Transaction pour gérer les réservations expirées
DELIMITER //
DROP PROCEDURE IF EXISTS GererReservationsExpirées //
CREATE PROCEDURE GererReservationsExpirées()
BEGIN
    START TRANSACTION;
    DELETE FROM Reservation
    WHERE Statut = 'notifiée'
    AND Date_expiration < CURDATE();
    UPDATE Reservation r
    JOIN Livre l ON r.Code_ISBN_re = l.Code_ISBN
    SET r.Date_notification = CURDATE(),
        r.Date_expiration = DATE_ADD(CURDATE(), INTERVAL 3 DAY),
        r.Statut = 'notifiée'
    WHERE r.Statut = 'en_attente'
    AND l.Nombre_exemplaires_disponibles > 0
    AND r.Id_reservation = (
        SELECT Id_reservation
        FROM Reservation
        WHERE Code_ISBN_re = r.Code_ISBN_re AND Statut = 'en_attente'
        ORDER BY Date_reservation ASC
        LIMIT 1
    );
    COMMIT;
END //
DELIMITER ;

-- 12. Insertion des données de test
-- Auteurs
INSERT IGNORE INTO Auteur (Nom, Prenom) VALUES
('Dupont', 'Jean'),
('Martin', 'Sophie'),
('Durand', 'Pierre'),
('Lefèvre', 'Marie'),
('Moreau', 'Luc');

-- Livres
INSERT IGNORE INTO Livre (Code_ISBN, Titre, Annee_edition, Editeur, Genre, Nombre_total_exemplaires, Nombre_exemplaires_disponibles, Valeur, Annee_derniere_depreciation) VALUES
('9781234567890', 'Les Misérables', 1862, 'Gallimard', 'roman', 0, 0, 15000.00, 2024),
('9781234567891', 'Introduction à la physique', 2015, 'Dunod', 'science', 0, 0, 20000.00, 2024),
('9781234567892', 'Histoire de France', 2010, 'Hachette', 'histoire', 0, 0, 18000.00, 2024),
('9781234567893', 'Le Petit Prince', 1943, 'Gallimard', 'roman', 0, 0, 12000.00, 2024),
('9781234567894', 'Chimie avancée', 2018, 'Pearson', 'science', 0, 0, 22000.00, 2024);

-- Association livres-auteurs
INSERT IGNORE INTO Livre_Auteur (Code_ISBN_la, Id_auteur_la) VALUES
('9781234567890', 1),
('9781234567891', 2),
('9781234567892', 3),
('9781234567893', 4),
('9781234567894', 5);

-- Exemplaires
INSERT IGNORE INTO Exemplaire (Code_exemplaire, Code_ISBN_exm, Statut) VALUES
('EX001', '9781234567890', 'disponible'),
('EX002', '9781234567891', 'disponible'),
('EX003', '9781234567892', 'disponible'),
('EX004', '9781234567893', 'disponible'),
('EX005', '9781234567894', 'disponible');

-- Adhérents
INSERT IGNORE INTO Adherent (Num_adherent, Nom, Prenom, Adresse, Telephone, Date_inscription) VALUES
('ADH001', 'Koffi', 'Ama', 'Abidjan', '0102030405', '2024-01-01'),
('ADH002', 'Yao', 'Kouassi', 'Yamoussoukro', '0203040506', '2024-02-01'),
('ADH003', 'Nguessan', 'Marie', 'Bouaké', '0304050607', '2024-03-01');

-- Abonnements
INSERT IGNORE INTO Abonnement (Num_adherent_ab, Date_debut, Date_fin, Statut, Montant) VALUES
('ADH001', '2024-04-01', '2024-04-30', 'actif', 5000.00),
('ADH002', '2024-04-01', '2024-04-30', 'actif', 5000.00),
('ADH003', '2024-04-01', '2024-04-30', 'actif', 5000.00);

-- Emprunts
INSERT IGNORE INTO Emprunt (Num_adherent_emp, Code_exemplaire_emp, Date_debut, Date_retour_prevue, Date_retour_effective) VALUES
('ADH001', 'EX001', '2024-04-01', '2024-04-16', NULL),
('ADH002', 'EX003', '2024-04-02', '2024-04-17', NULL),
('ADH003', 'EX004', '2024-04-03', '2024-04-18', '2024-04-20');

-- Réservations
INSERT IGNORE INTO Reservation (Num_adherent_re, Code_ISBN_re, Date_reservation, Date_notification, Date_expiration, Statut) VALUES
('ADH001', '9781234567891', '2024-04-01', NULL, NULL, 'en_attente'),
('ADH002', '9781234567892', '2024-04-02', NULL, NULL, 'en_attente'),
('ADH003', '9781234567890', '2024-04-03', '2024-04-04', '2024-04-07', 'notifiée');

-- Suppression de 2 exemplaires égarés
CALL SupprimerExemplaireEgare('EX002', 'ADH001');
CALL SupprimerExemplaireEgare('EX005', 'ADH002');

-- 13. Requête pour afficher les livres de genre "science" empruntés par chaque adhérent
SELECT a.Num_adherent, a.Nom, a.Prenom, l.Titre, l.Code_ISBN
FROM Adherent a
JOIN Emprunt e ON a.Num_adherent = e.Num_adherent_emp
JOIN Exemplaire ex ON e.Code_exemplaire_emp = ex.Code_exemplaire
JOIN Livre l ON ex.Code_ISBN_exm = l.Code_ISBN
WHERE l.Genre = 'science'
ORDER BY a.Num_adherent;