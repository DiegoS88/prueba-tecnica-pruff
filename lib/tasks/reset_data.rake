# Borra todos los datos de negocio (facturas, movimientos, aplicaciones,
# importaciones, auditoría y snapshots) conservando los usuarios.
# Uso: bin/rails demo:reset_data
namespace :demo do
  desc "Limpia los datos de la demo conservando los usuarios"
  task reset_data: :environment do
    puts "Borrando payment_applications..."
    PaymentApplication.delete_all
    puts "Borrando audit_events..."
    AuditEvent.delete_all
    puts "Borrando movimientos..."
    Movement.delete_all
    puts "Borrando facturas..."
    Invoice.delete_all
    puts "Borrando importaciones..."
    Import.delete_all
    puts "Borrando snapshots..."
    PortfolioSnapshot.delete_all

    puts "Datos limpiados. Quedan #{User.count} usuarios."
    puts "Vuelve a cargar los CSV desde Importar → Nueva importación."
  end
end