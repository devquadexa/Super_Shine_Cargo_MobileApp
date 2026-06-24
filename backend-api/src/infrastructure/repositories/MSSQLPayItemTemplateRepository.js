const IPayItemTemplateRepository = require('../../domain/repositories/IPayItemTemplateRepository');

class MSSQLPayItemTemplateRepository extends IPayItemTemplateRepository {
  constructor(getConnection, sqlModule) {
    super();
    this.getConnection = getConnection;
    this.sql = sqlModule;
  }

  async getByCategory(shipmentCategory) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('ShipmentCategory', this.sql.NVarChar(100), shipmentCategory)
        .execute('usp_GetPayItemTemplatesByCategory');

      // Backward compatibility: fall back to legacy 'Vehicle' category if new sub-type has no templates
      const isNewVehicleCategory = shipmentCategory === 'Vehicle - Personal' || shipmentCategory === 'Vehicle - Company';
      if (result.recordset.length === 0 && isNewVehicleCategory) {
        const fallback = await pool.request()
          .input('ShipmentCategory', this.sql.NVarChar(100), 'Vehicle')
          .execute('usp_GetPayItemTemplatesByCategory');

        return fallback.recordset;
      }

      return result.recordset;
    } catch (error) {
      console.error('Error fetching pay item templates by category:', error);
      throw error;
    }
  }

  async getAll() {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .execute('usp_GetAllPayItemTemplates');

      // Group by category
      const grouped = {};
      result.recordset.forEach(item => {
        if (!grouped[item.shipmentCategory]) grouped[item.shipmentCategory] = [];
        grouped[item.shipmentCategory].push(item);
      });

      return grouped;
    } catch (error) {
      console.error('Error fetching all pay item templates:', error);
      throw error;
    }
  }

  async create(templateData) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('ShipmentCategory', this.sql.NVarChar(100), templateData.shipmentCategory)
        .input('ItemName',         this.sql.NVarChar(500), templateData.itemName)
        .execute('usp_CreatePayItemTemplate');

      return result.recordset[0];
    } catch (error) {
      console.error('Error creating pay item template:', error);
      throw error;
    }
  }

  async update(templateId, templateData) {
    try {
      const pool = await this.getConnection();

      const result = await pool.request()
        .input('TemplateId', this.sql.Int,          templateId)
        .input('ItemName',   this.sql.NVarChar(500), templateData.itemName)
        .execute('usp_UpdatePayItemTemplate');

      return result.recordset[0];
    } catch (error) {
      console.error('Error updating pay item template:', error);
      throw error;
    }
  }

  async delete(templateId) {
    try {
      const pool = await this.getConnection();

      await pool.request()
        .input('TemplateId', this.sql.Int, templateId)
        .execute('usp_DeletePayItemTemplate');

      return { success: true };
    } catch (error) {
      console.error('Error deleting pay item template:', error);
      throw error;
    }
  }

  async reorder(shipmentCategory, items) {
    try {
      const pool = await this.getConnection();
      const transaction = new this.sql.Transaction(pool);

      await transaction.begin();
      try {
        for (let i = 0; i < items.length; i++) {
          await transaction.request()
            .input('TemplateId', this.sql.Int, items[i].templateId)
            .input('ItemOrder',  this.sql.Int, i + 1)
            .execute('usp_ReorderPayItemTemplate');
        }

        await transaction.commit();
        return { success: true };
      } catch (error) {
        await transaction.rollback();
        throw error;
      }
    } catch (error) {
      console.error('Error reordering pay item templates:', error);
      throw error;
    }
  }
}

module.exports = MSSQLPayItemTemplateRepository;
