/**
 * MSSQL User Repository Implementation
 * All database operations are delegated to stored procedures.
 */
const IUserRepository = require('../../domain/repositories/IUserRepository');
const User = require('../../domain/entities/User');
const bcrypt = require('bcryptjs');

class MSSQLUserRepository extends IUserRepository {
  constructor(dbConnection, sql) {
    super();
    this.db = dbConnection;
    this.sql = sql;
  }

  async create(user) {
    const pool = await this.db();

    await pool.request()
      .input('UserId',               this.sql.VarChar(50),  user.userId)
      .input('Username',             this.sql.VarChar(100), user.username)
      .input('Password',             this.sql.VarChar(255), user.password)
      .input('FullName',             this.sql.VarChar(255), user.fullName)
      .input('Role',                 this.sql.VarChar(50),  user.role)
      .input('Email',                this.sql.VarChar(255), user.email)
      .input('CreatedDate',          this.sql.DateTime,     user.createdDate)
      .input('IsActive',             this.sql.Bit,          user.isActive)
      .input('IsTemporaryPassword',  this.sql.Bit,          user.isTemporaryPassword  || false)
      .input('PasswordResetRequired',this.sql.Bit,          user.passwordResetRequired || false)
      .input('LastPasswordChange',   this.sql.DateTime,     user.lastPasswordChange   || new Date())
      .execute('usp_CreateUser');

    return user;
  }

  async findById(userId) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_GetUserById');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findByUsername(username) {
    const pool = await this.db();

    const result = await pool.request()
      .input('Username', this.sql.VarChar(100), username)
      .execute('usp_GetUserByUsername');

    if (result.recordset.length === 0) return null;
    return this.mapToEntity(result.recordset[0]);
  }

  async findAll() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GetAllUsers');

    return result.recordset.map(row => this.mapToEntity(row));
  }

  async update(userId, user) {
    const pool = await this.db();

    await pool.request()
      .input('UserId',   this.sql.VarChar(50),  userId)
      .input('FullName', this.sql.VarChar(255), user.fullName)
      .input('Role',     this.sql.VarChar(50),  user.role)
      .input('Email',    this.sql.VarChar(255), user.email)
      .execute('usp_UpdateUser');

    return user;
  }

  async delete(userId) {
    const pool = await this.db();

    await pool.request()
      .input('UserId', this.sql.VarChar(50), userId)
      .execute('usp_DeleteUser');

    return true;
  }

  async authenticate(username, password) {
    const pool = await this.db();

    const result = await pool.request()
      .input('UserName', this.sql.VarChar(100), username)
      .execute('usp_AuthenticateUser');

    if (result.recordset.length === 0) return null;

    const user = this.mapToEntity(result.recordset[0]);

    // Bcrypt hashes always start with $2a$, $2b$, or $2y$
    const isHashed = user.password && user.password.startsWith('$2');
    let isValid = false;

    if (isHashed) {
      isValid = await bcrypt.compare(password, user.password);
    } else {
      // Legacy plain-text comparison
      isValid = (password === user.password);

      // Non-blocking upgrade: hash and persist on successful plain-text login
      if (isValid) {
        try {
          const hashed = await bcrypt.hash(password, 10);
          await this.updatePassword(user.userId, hashed, false, false);
          console.log(`✅ Migrated password to bcrypt for user: ${username}`);
        } catch (err) {
          console.error(`⚠️ Failed to migrate password for user: ${username}`, err);
        }
      }
    }

    if (!isValid) return null;
    return user;
  }

  async generateNextId() {
    const pool = await this.db();

    const result = await pool.request()
      .execute('usp_GenerateNextUserId');

    return result.recordset[0].NextUserId;
  }

  async updatePassword(userId, hashedPassword, isTemporaryPassword = false, passwordResetRequired = false) {
    const pool = await this.db();

    await pool.request()
      .input('UserId',               this.sql.VarChar(50),  userId)
      .input('Password',             this.sql.VarChar(255), hashedPassword)
      .input('IsTemporaryPassword',  this.sql.Bit,          isTemporaryPassword)
      .input('PasswordResetRequired',this.sql.Bit,          passwordResetRequired)
      .execute('usp_UpdateUserPassword');
  }

  mapToEntity(row) {
    return new User({
      userId:                row.UserId,
      username:              row.Username,
      password:              row.Password,
      fullName:              row.FullName,
      role:                  row.Role,
      email:                 row.Email,
      createdDate:           row.CreatedDate,
      isActive:              row.IsActive,
      isTemporaryPassword:   row.isTemporaryPassword,
      passwordResetRequired: row.passwordResetRequired,
      lastPasswordChange:    row.lastPasswordChange
    });
  }
}

module.exports = MSSQLUserRepository;
