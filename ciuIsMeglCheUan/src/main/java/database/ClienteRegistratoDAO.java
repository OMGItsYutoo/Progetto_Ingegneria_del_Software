package database;

import entity.Accessorio;
import entity.ClienteRegistrato;
import exception.DAOException;
import exception.DBConnectionException;

import java.sql.*;

public class ClienteRegistratoDAO {

    public static int createClienteRegistrato(ClienteRegistrato cliente) throws DBConnectionException, DAOException {
        try {
            Connection conn = DBManager.getConnection();
            String query = "INSERT INTO ClientiRegistrati (nome, cognome, dataDiNascita, email, password) VALUES (?, ?, ?, ?, ?);";

            try (PreparedStatement ps = conn.prepareStatement(query, Statement.RETURN_GENERATED_KEYS)) {
                ps.setString(1, cliente.getNome());
                ps.setString(2, cliente.getCognome());
                ps.setString(3, cliente.getDataDiNascita());
                ps.setString(4, cliente.getEmail());
                ps.setString(5, cliente.getPassword());

                int affectedRows = ps.executeUpdate();
                if (affectedRows == 0) {
                    throw new DAOException("Errore creazione ClienteRegistrato");
                }

                try (ResultSet generatedKeys = ps.getGeneratedKeys()) {
                    if (generatedKeys.next()) {
                        int id = generatedKeys.getInt(1);
                        cliente.setId(id);
                        return id;
                    }
                }
                return affectedRows;
            } catch (SQLException e) {
                throw new DAOException("Errore creazione ClienteRegistrato");
            } finally {
                DBManager.closeConnection();
            }
        } catch (SQLException e) {
            throw new DBConnectionException("Errore connessione al database");
        }
    }

    public static ClienteRegistrato readClienteRegistrato(String email) throws DBConnectionException, DAOException {
        try {
            Connection conn = DBManager.getConnection();

            String query = "SELECT * FROM ClientiRegistrati Where email=?;";

            try {
                PreparedStatement ps = conn.prepareStatement(query);

                ps.setString(1, email);

                ResultSet rs = ps.executeQuery();

                if (rs.next()) {
                    int id = rs.getInt("id");
                    String nome = rs.getString("nome");
                    String cognome = rs.getString("cognome");
                    String dataDiNascita = rs.getString("dataDiNascita");
                    String emailq = rs.getString("email");
                    String password = rs.getString("password");

                    ClienteRegistrato cr = new ClienteRegistrato(nome, cognome, dataDiNascita, emailq, password);
                    cr.setId(id);
                    return cr;
                }
            } catch (SQLException e) {
                throw new DAOException("Errore lettura ClienteRegistrato");
            } finally {
                DBManager.closeConnection();
            }
        }catch(SQLException e){
            throw new DBConnectionException("Errore connessione al database");
        }
        return null;
    }

    public static int updateClienteRegistrato() {
        return 0;
    }

    public static int deleteClienteRegistrato() {
        return 0;
    }
}
