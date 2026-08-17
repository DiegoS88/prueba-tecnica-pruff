class ImportsController < ApplicationController
  def new
    @import = Import.new
  end

  def create
    file = params[:import][:file]
    kind = params[:import][:kind]

    if file.blank? || kind.blank?
      return redirect_to new_import_path, alert: "Selecciona un archivo CSV y un tipo."
    end

    result = ImportService.new(kind: kind, file: file, user: Current.user).call

    if result.ok
      redirect_to imports_path, notice: import_notice(result)
    else
      redirect_to new_import_path, alert: "Error al importar: #{result.errors.first}"
    end
  rescue ActionController::ParameterMissing
    redirect_to new_import_path, alert: "Falta el archivo."
  end

  def index
    @imports = Import.order(created_at: :desc).includes(:user)
  end

  private

  def import_notice(result)
    if result.reimported
      return "Este archivo ya había sido importado (id ##{result.import.id}). No se duplicó nada."
    end

    counts = result.import.summary
    "Import completado: #{counts[:imported]} nuevos, #{counts[:updated]} actualizados, #{counts[:duplicates]} duplicados, #{counts[:errors]} errores."
  end
end
