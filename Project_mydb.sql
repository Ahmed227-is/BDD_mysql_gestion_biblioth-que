-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Hôte : localhost
-- Généré le : dim. 06 avr. 2025 à 09:53
-- Version du serveur : 10.6.19-MariaDB
-- Version de PHP : 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de données : `mydb`
--
CREATE DATABASE IF NOT EXISTS `mydb` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `mydb`;

DELIMITER $$
--
-- Procédures
--
DROP PROCEDURE IF EXISTS `EnregistrerRetour`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `EnregistrerRetour` (IN `p_id_emprunt` INT, IN `p_date_retour` DATE)   BEGIN
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
END$$

DROP PROCEDURE IF EXISTS `GererReservationsExpirées`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `GererReservationsExpirées` ()   BEGIN
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
END$$

DROP PROCEDURE IF EXISTS `SupprimerExemplaireEgare`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `SupprimerExemplaireEgare` (IN `p_code_exemplaire` VARCHAR(20), IN `p_num_adherent` VARCHAR(10))   BEGIN
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
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `abonnement`
--

DROP TABLE IF EXISTS `abonnement`;
CREATE TABLE IF NOT EXISTS `abonnement` (
  `Id_abonnement` int(11) NOT NULL AUTO_INCREMENT,
  `Num_adherent_ab` varchar(10) NOT NULL,
  `Date_debut` date NOT NULL,
  `Date_fin` date NOT NULL,
  `Statut` enum('actif','expiré') DEFAULT 'actif',
  `Montant` decimal(10,2) DEFAULT 5000.00,
  PRIMARY KEY (`Id_abonnement`),
  KEY `Num_adherent_idx` (`Num_adherent_ab`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `abonnement`:
--   `Num_adherent_ab`
--       `adherent` -> `Num_adherent`
--

--
-- Déchargement des données de la table `abonnement`
--

INSERT IGNORE INTO `abonnement` (`Id_abonnement`, `Num_adherent_ab`, `Date_debut`, `Date_fin`, `Statut`, `Montant`) VALUES
(1, 'ADH001', '2024-04-01', '2024-04-30', 'expiré', 5000.00),
(2, 'ADH002', '2024-04-01', '2024-04-30', 'expiré', 5000.00),
(3, 'ADH003', '2024-04-01', '2024-04-30', 'expiré', 5000.00),
(4, 'ADH001', '2024-04-01', '2024-04-30', 'actif', 5000.00),
(5, 'ADH002', '2024-04-01', '2024-04-30', 'actif', 5000.00),
(6, 'ADH003', '2024-04-01', '2024-04-30', 'actif', 5000.00);

-- --------------------------------------------------------

--
-- Structure de la table `adherent`
--

DROP TABLE IF EXISTS `adherent`;
CREATE TABLE IF NOT EXISTS `adherent` (
  `Num_adherent` varchar(10) NOT NULL,
  `Nom` varchar(255) NOT NULL,
  `Prenom` varchar(255) NOT NULL,
  `Adresse` mediumtext NOT NULL,
  `Telephone` varchar(10) NOT NULL,
  `Date_inscription` date NOT NULL,
  PRIMARY KEY (`Num_adherent`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `adherent`:
--

--
-- Déchargement des données de la table `adherent`
--

INSERT IGNORE INTO `adherent` (`Num_adherent`, `Nom`, `Prenom`, `Adresse`, `Telephone`, `Date_inscription`) VALUES
('ADH001', 'Koffi', 'Ama', 'Abidjan', '0102030405', '2024-01-01'),
('ADH002', 'Yao', 'Kouassi', 'Yamoussoukro', '0203040506', '2024-02-01'),
('ADH003', 'Nguessan', 'Marie', 'Bouaké', '0304050607', '2024-03-01');

-- --------------------------------------------------------

--
-- Structure de la table `auteur`
--

DROP TABLE IF EXISTS `auteur`;
CREATE TABLE IF NOT EXISTS `auteur` (
  `Id_auteur` int(11) NOT NULL AUTO_INCREMENT,
  `Nom` varchar(255) NOT NULL,
  `Prenom` varchar(255) NOT NULL,
  PRIMARY KEY (`Id_auteur`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `auteur`:
--

--
-- Déchargement des données de la table `auteur`
--

INSERT IGNORE INTO `auteur` (`Id_auteur`, `Nom`, `Prenom`) VALUES
(1, 'Dupont', 'Jean'),
(2, 'Martin', 'Sophie'),
(3, 'Durand', 'Pierre'),
(4, 'Lefèvre', 'Marie'),
(5, 'Moreau', 'Luc'),
(6, 'Dupont', 'Jean'),
(7, 'Martin', 'Sophie'),
(8, 'Durand', 'Pierre'),
(9, 'Lefèvre', 'Marie'),
(10, 'Moreau', 'Luc'),
(11, 'Dupont', 'Jean'),
(12, 'Martin', 'Sophie'),
(13, 'Durand', 'Pierre'),
(14, 'Lefèvre', 'Marie'),
(15, 'Moreau', 'Luc'),
(16, 'Dupont', 'Jean'),
(17, 'Martin', 'Sophie'),
(18, 'Durand', 'Pierre'),
(19, 'Lefèvre', 'Marie'),
(20, 'Moreau', 'Luc'),
(21, 'Dupont', 'Jean'),
(22, 'Martin', 'Sophie'),
(23, 'Durand', 'Pierre'),
(24, 'Lefèvre', 'Marie'),
(25, 'Moreau', 'Luc'),
(26, 'Dupont', 'Jean'),
(27, 'Martin', 'Sophie'),
(28, 'Durand', 'Pierre'),
(29, 'Lefèvre', 'Marie'),
(30, 'Moreau', 'Luc'),
(31, 'Dupont', 'Jean'),
(32, 'Martin', 'Sophie'),
(33, 'Durand', 'Pierre'),
(34, 'Lefèvre', 'Marie'),
(35, 'Moreau', 'Luc'),
(36, 'Dupont', 'Jean'),
(37, 'Martin', 'Sophie'),
(38, 'Durand', 'Pierre'),
(39, 'Lefèvre', 'Marie'),
(40, 'Moreau', 'Luc');

-- --------------------------------------------------------

--
-- Structure de la table `emprunt`
--

DROP TABLE IF EXISTS `emprunt`;
CREATE TABLE IF NOT EXISTS `emprunt` (
  `Id_emprunt` int(11) NOT NULL AUTO_INCREMENT,
  `Num_adherent_emp` varchar(10) NOT NULL,
  `Code_exemplaire_emp` varchar(20) DEFAULT NULL,
  `Date_debut` date NOT NULL,
  `Date_retour_prevue` date NOT NULL,
  `Date_retour_effective` date DEFAULT NULL,
  PRIMARY KEY (`Id_emprunt`,`Num_adherent_emp`),
  KEY `Num_adherent_idx` (`Num_adherent_emp`),
  KEY `Code_exemplaire_idx` (`Code_exemplaire_emp`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `emprunt`:
--   `Code_exemplaire_emp`
--       `exemplaire` -> `Code_exemplaire`
--   `Num_adherent_emp`
--       `adherent` -> `Num_adherent`
--

--
-- Déchargement des données de la table `emprunt`
--

INSERT IGNORE INTO `emprunt` (`Id_emprunt`, `Num_adherent_emp`, `Code_exemplaire_emp`, `Date_debut`, `Date_retour_prevue`, `Date_retour_effective`) VALUES
(1, 'ADH001', 'EX001', '2024-04-01', '2024-04-16', NULL),
(2, 'ADH002', 'EX003', '2024-04-02', '2024-04-17', NULL),
(3, 'ADH003', 'EX004', '2024-04-03', '2024-04-18', '2024-04-20');

--
-- Déclencheurs `emprunt`
--
DROP TRIGGER IF EXISTS `after_emprunt_insert`;
DELIMITER $$
CREATE TRIGGER `after_emprunt_insert` AFTER INSERT ON `emprunt` FOR EACH ROW BEGIN
    UPDATE Exemplaire
    SET Statut = 'emprunté'
    WHERE Code_exemplaire = NEW.Code_exemplaire_emp;
    UPDATE Livre
    SET Nombre_exemplaires_disponibles = Nombre_exemplaires_disponibles - 1
    WHERE Code_ISBN = (SELECT Code_ISBN_exm FROM Exemplaire WHERE Code_exemplaire = NEW.Code_exemplaire_emp);
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `after_emprunt_update`;
DELIMITER $$
CREATE TRIGGER `after_emprunt_update` AFTER UPDATE ON `emprunt` FOR EACH ROW BEGIN
    IF NEW.Date_retour_effective IS NOT NULL AND OLD.Date_retour_effective IS NULL THEN
        UPDATE Exemplaire
        SET Statut = 'disponible'
        WHERE Code_exemplaire = NEW.Code_exemplaire_emp;
        UPDATE Livre
        SET Nombre_exemplaires_disponibles = Nombre_exemplaires_disponibles + 1
        WHERE Code_ISBN = (SELECT Code_ISBN_exm FROM Exemplaire WHERE Code_exemplaire = NEW.Code_exemplaire_emp);
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `before_emprunt_insert_duplicate`;
DELIMITER $$
CREATE TRIGGER `before_emprunt_insert_duplicate` BEFORE INSERT ON `emprunt` FOR EACH ROW BEGIN
    DECLARE livre_deja_emprunte INT;
    SELECT COUNT(*) INTO livre_deja_emprunte
    FROM Emprunt e
    JOIN Exemplaire ex ON e.Code_exemplaire_emp = ex.Code_exemplaire
    WHERE e.Num_adherent_emp = NEW.Num_adherent_emp
    AND ex.Code_ISBN_exm = (SELECT Code_ISBN_exm FROM Exemplaire WHERE Code_exemplaire = NEW.Code_exemplaire_emp)
    AND e.Date_retour_effective IS NULL;
    IF livre_deja_emprunte > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erreur : L''adhérent a déjà emprunté un exemplaire de ce livre.';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `before_emprunt_insert_limit`;
DELIMITER $$
CREATE TRIGGER `before_emprunt_insert_limit` BEFORE INSERT ON `emprunt` FOR EACH ROW BEGIN
    DECLARE nombre_emprunts INT;
    SELECT COUNT(*) INTO nombre_emprunts
    FROM Emprunt
    WHERE Num_adherent_emp = NEW.Num_adherent_emp AND Date_retour_effective IS NULL;
    IF nombre_emprunts >= 3 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erreur : L''adhérent a déjà 3 emprunts actifs.';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `before_emprunt_insert_penalite`;
DELIMITER $$
CREATE TRIGGER `before_emprunt_insert_penalite` BEFORE INSERT ON `emprunt` FOR EACH ROW BEGIN
    DECLARE penalites_non_payees INT;
    SELECT COUNT(*) INTO penalites_non_payees
    FROM penalite
    WHERE Num_adherent_pn = NEW.Num_adherent_emp AND Statut = 'non_payée';
    IF penalites_non_payees > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Erreur : L''adhérent a des pénalités non payées.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `exemplaire`
--

DROP TABLE IF EXISTS `exemplaire`;
CREATE TABLE IF NOT EXISTS `exemplaire` (
  `Code_exemplaire` varchar(20) NOT NULL,
  `Code_ISBN_exm` varchar(13) DEFAULT NULL,
  `Statut` enum('disponible','emprunte','reserve','perdu') DEFAULT 'disponible',
  PRIMARY KEY (`Code_exemplaire`),
  KEY `Code_ISBN_idx` (`Code_ISBN_exm`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `exemplaire`:
--   `Code_ISBN_exm`
--       `livre` -> `Code_ISBN`
--

--
-- Déchargement des données de la table `exemplaire`
--

INSERT IGNORE INTO `exemplaire` (`Code_exemplaire`, `Code_ISBN_exm`, `Statut`) VALUES
('EX001', '9781234567890', 'emprunte'),
('EX002', '9781234567890', 'disponible'),
('EX003', '9781234567891', 'emprunte'),
('EX004', '9781234567892', 'emprunte'),
('EX005', '9781234567893', 'disponible');

--
-- Déclencheurs `exemplaire`
--
DROP TRIGGER IF EXISTS `after_exemplaire_delete`;
DELIMITER $$
CREATE TRIGGER `after_exemplaire_delete` AFTER DELETE ON `exemplaire` FOR EACH ROW BEGIN
    UPDATE Livre
    SET Nombre_total_exemplaires = Nombre_total_exemplaires - 1,
        Nombre_exemplaires_disponibles = Nombre_exemplaires_disponibles - 1
    WHERE Code_ISBN = OLD.Code_ISBN_exm;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `after_exemplaire_insert`;
DELIMITER $$
CREATE TRIGGER `after_exemplaire_insert` AFTER INSERT ON `exemplaire` FOR EACH ROW BEGIN
    UPDATE Livre
    SET Nombre_total_exemplaires = Nombre_total_exemplaires + 1,
        Nombre_exemplaires_disponibles = Nombre_exemplaires_disponibles + 1
    WHERE Code_ISBN = NEW.Code_ISBN_exm;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `livre`
--

DROP TABLE IF EXISTS `livre`;
CREATE TABLE IF NOT EXISTS `livre` (
  `Code_ISBN` varchar(13) NOT NULL,
  `Titre` varchar(255) NOT NULL,
  `Annee_edition` int(11) DEFAULT NULL,
  `Editeur` varchar(100) DEFAULT NULL,
  `Genre` varchar(45) DEFAULT NULL,
  `Nombre_total_exemplaires` int(11) NOT NULL DEFAULT 0,
  `Nombre_exemplaires_disponibles` int(11) NOT NULL DEFAULT 0,
  `Valeur` decimal(10,2) NOT NULL,
  `Annee_derniere_depreciation` int(11) DEFAULT NULL,
  PRIMARY KEY (`Code_ISBN`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `livre`:
--

--
-- Déchargement des données de la table `livre`
--

INSERT IGNORE INTO `livre` (`Code_ISBN`, `Titre`, `Annee_edition`, `Editeur`, `Genre`, `Nombre_total_exemplaires`, `Nombre_exemplaires_disponibles`, `Valeur`, `Annee_derniere_depreciation`) VALUES
('9781234567890', 'Les Misérables', 1862, 'Gallimard', 'roman', 2, 1, 15000.00, 2024),
('9781234567891', 'Introduction à la physique', 2015, 'Dunod', 'science', 1, 0, 20000.00, 2024),
('9781234567892', 'Histoire de France', 2010, 'Hachette', 'histoire', 1, 0, 18000.00, 2024),
('9781234567893', 'Le Petit Prince', 1943, 'Gallimard', 'roman', 1, 1, 12000.00, 2024),
('9781234567894', 'Chimie avancée', 2018, 'Pearson', 'science', 0, 0, 22000.00, 2024);

-- --------------------------------------------------------

--
-- Structure de la table `livre_auteur`
--

DROP TABLE IF EXISTS `livre_auteur`;
CREATE TABLE IF NOT EXISTS `livre_auteur` (
  `Id_auteur_la` int(11) NOT NULL AUTO_INCREMENT,
  `Code_ISBN_la` varchar(13) NOT NULL,
  PRIMARY KEY (`Id_auteur_la`,`Code_ISBN_la`),
  KEY `Id_auteur_idx` (`Id_auteur_la`),
  KEY `Code_ISBN_la` (`Code_ISBN_la`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `livre_auteur`:
--   `Code_ISBN_la`
--       `livre` -> `Code_ISBN`
--   `Id_auteur_la`
--       `auteur` -> `Id_auteur`
--

--
-- Déchargement des données de la table `livre_auteur`
--

INSERT IGNORE INTO `livre_auteur` (`Id_auteur_la`, `Code_ISBN_la`) VALUES
(1, '9781234567890'),
(2, '9781234567891'),
(3, '9781234567892'),
(4, '9781234567893'),
(5, '9781234567894');

-- --------------------------------------------------------

--
-- Structure de la table `penalite`
--

DROP TABLE IF EXISTS `penalite`;
CREATE TABLE IF NOT EXISTS `penalite` (
  `Id_penalite` int(11) NOT NULL AUTO_INCREMENT,
  `Num_adherent_pn` varchar(10) DEFAULT NULL,
  `Id_emprunt_pn` int(11) DEFAULT NULL,
  `Montant` decimal(10,2) NOT NULL,
  `Date_creation` date NOT NULL,
  `Statut` enum('payée','non_payée') DEFAULT 'non_payée',
  `Type_penalite` enum('retard','perte') NOT NULL,
  PRIMARY KEY (`Id_penalite`),
  KEY `Num_adherent_idx` (`Num_adherent_pn`),
  KEY `Id_emprunt_idx` (`Id_emprunt_pn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `penalite`:
--   `Id_emprunt_pn`
--       `emprunt` -> `Id_emprunt`
--   `Num_adherent_pn`
--       `adherent` -> `Num_adherent`
--

-- --------------------------------------------------------

--
-- Structure de la table `reservation`
--

DROP TABLE IF EXISTS `reservation`;
CREATE TABLE IF NOT EXISTS `reservation` (
  `Id_reservation` int(11) NOT NULL AUTO_INCREMENT,
  `Num_adherent_re` varchar(10) DEFAULT NULL,
  `Code_ISBN_re` varchar(13) DEFAULT NULL,
  `Date_reservation` date NOT NULL,
  `Date_notification` date DEFAULT NULL,
  `Date_expiration` date NOT NULL,
  `Statut` enum('en_attente','notifiée','expirée','annulée') DEFAULT 'en_attente',
  PRIMARY KEY (`Id_reservation`),
  KEY `Code_ISBN_idx` (`Code_ISBN_re`),
  KEY `Num_adherent_idx` (`Num_adherent_re`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- RELATIONS POUR LA TABLE `reservation`:
--   `Code_ISBN_re`
--       `livre` -> `Code_ISBN`
--   `Num_adherent_re`
--       `adherent` -> `Num_adherent`
--

--
-- Déchargement des données de la table `reservation`
--

INSERT IGNORE INTO `reservation` (`Id_reservation`, `Num_adherent_re`, `Code_ISBN_re`, `Date_reservation`, `Date_notification`, `Date_expiration`, `Statut`) VALUES
(1, 'ADH001', '9781234567891', '2024-04-01', NULL, '0000-00-00', 'en_attente'),
(2, 'ADH002', '9781234567891', '2024-04-02', NULL, '0000-00-00', 'en_attente'),
(3, 'ADH003', '9781234567890', '2024-04-03', '2024-04-04', '2024-04-07', 'notifiée');

--
-- Contraintes pour les tables déchargées
--

--
-- Contraintes pour la table `abonnement`
--
ALTER TABLE `abonnement`
  ADD CONSTRAINT `Num_adherent_ab` FOREIGN KEY (`Num_adherent_ab`) REFERENCES `adherent` (`Num_adherent`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- Contraintes pour la table `emprunt`
--
ALTER TABLE `emprunt`
  ADD CONSTRAINT `Code_exemplaire_emp` FOREIGN KEY (`Code_exemplaire_emp`) REFERENCES `exemplaire` (`Code_exemplaire`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `Num_adherent_emp` FOREIGN KEY (`Num_adherent_emp`) REFERENCES `adherent` (`Num_adherent`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- Contraintes pour la table `exemplaire`
--
ALTER TABLE `exemplaire`
  ADD CONSTRAINT `Code_ISBN_exm` FOREIGN KEY (`Code_ISBN_exm`) REFERENCES `livre` (`Code_ISBN`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- Contraintes pour la table `livre_auteur`
--
ALTER TABLE `livre_auteur`
  ADD CONSTRAINT `Code_ISBN_la` FOREIGN KEY (`Code_ISBN_la`) REFERENCES `livre` (`Code_ISBN`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `Id_auteur_la` FOREIGN KEY (`Id_auteur_la`) REFERENCES `auteur` (`Id_auteur`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- Contraintes pour la table `penalite`
--
ALTER TABLE `penalite`
  ADD CONSTRAINT `Id_emprunt_pn` FOREIGN KEY (`Id_emprunt_pn`) REFERENCES `emprunt` (`Id_emprunt`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `Num_adherent_pn` FOREIGN KEY (`Num_adherent_pn`) REFERENCES `adherent` (`Num_adherent`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- Contraintes pour la table `reservation`
--
ALTER TABLE `reservation`
  ADD CONSTRAINT `Code_ISBN_re` FOREIGN KEY (`Code_ISBN_re`) REFERENCES `livre` (`Code_ISBN`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  ADD CONSTRAINT `Num_adherent_re` FOREIGN KEY (`Num_adherent_re`) REFERENCES `adherent` (`Num_adherent`) ON DELETE NO ACTION ON UPDATE NO ACTION;


--
-- Métadonnées
--
USE `phpmyadmin`;

--
-- Métadonnées pour la table abonnement
--

--
-- Métadonnées pour la table adherent
--

--
-- Métadonnées pour la table auteur
--

--
-- Métadonnées pour la table emprunt
--

--
-- Métadonnées pour la table exemplaire
--

--
-- Métadonnées pour la table livre
--

--
-- Métadonnées pour la table livre_auteur
--

--
-- Métadonnées pour la table penalite
--

--
-- Métadonnées pour la table reservation
--

--
-- Métadonnées pour la base de données mydb
--
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
